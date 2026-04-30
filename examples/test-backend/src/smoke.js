/**
 * End-to-end smoke test: simulates two devices syncing through the
 * backend. No external HTTP calls — boots the express app in-process.
 *
 * Run with: `npm run smoke`
 */
const http = require('http');
const { randomUUID } = require('crypto');
const { app, initDb } = require('./server');

const PORT = 0; // ephemeral

function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        host: '127.0.0.1',
        port: PORT_BOUND,
        method,
        path,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': data ? Buffer.byteLength(data) : 0,
        },
      },
      (res) => {
        let chunks = '';
        res.on('data', (c) => (chunks += c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(chunks || '{}') });
          } catch (e) {
            reject(new Error(`bad JSON from ${path}: ${chunks}`));
          }
        });
      },
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

let PORT_BOUND;

async function main() {
  // Reset DB by running against an in-memory copy via env.
  process.env.DB_PATH = ':memory:';
  // Re-require db.js after env change so the in-memory path takes effect.
  delete require.cache[require.resolve('./db')];
  delete require.cache[require.resolve('./server')];
  delete require.cache[require.resolve('./routes/sync')];
  const { app: freshApp, initDb: freshInit } = require('./server');
  freshInit();

  const server = http.createServer(freshApp);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  PORT_BOUND = server.address().port;

  const log = (...a) => console.log('[smoke]', ...a);

  try {
    // ── Device A inserts a row ────────────────────────────────────────
    const id = randomUUID();
    const t0 = Date.now();
    log(`[A] inserting row ${id}`);
    const push1 = await request('POST', '/sync/things', {
      changes: [
        {
          operation: 'insert',
          payload: {
            id,
            created_at: t0,
            updated_at: t0,
            deleted_at: null,
            is_synced: 0,
            sync_status: 'pending',
            name: 'Apple',
          },
        },
      ],
    });
    if (push1.status !== 200 || push1.body.results[0].status !== 'ok') {
      throw new Error('A insert failed: ' + JSON.stringify(push1.body));
    }
    log('[A] insert OK; server_time =', push1.body.server_time);

    // ── Device B pulls everything ─────────────────────────────────────
    log('[B] pulling all (since=null)');
    const pull1 = await request('GET', '/sync/things');
    if (pull1.status !== 200 || pull1.body.rows.length !== 1) {
      throw new Error('B pull-all unexpected: ' + JSON.stringify(pull1.body));
    }
    const seenAtB = pull1.body.rows[0];
    if (seenAtB.id !== id || seenAtB.name !== 'Apple') {
      throw new Error('B saw wrong row: ' + JSON.stringify(seenAtB));
    }
    const lastSyncB = pull1.body.server_time;
    log('[B] saw row from A; lastSync =', lastSyncB);

    // ── Device B updates the row ──────────────────────────────────────
    const t1 = Date.now() + 1000; // simulate later wall-clock
    log('[B] renaming Apple → Pineapple');
    const push2 = await request('POST', '/sync/things', {
      changes: [
        {
          operation: 'update',
          payload: {
            id,
            created_at: seenAtB.created_at,
            updated_at: t1,
            deleted_at: null,
            is_synced: 0,
            sync_status: 'pending',
            name: 'Pineapple',
          },
        },
      ],
    });
    if (push2.body.results[0].status !== 'ok') {
      throw new Error('B update failed: ' + JSON.stringify(push2.body));
    }
    log('[B] update OK');

    // ── Device A pulls deltas since its last sync ─────────────────────
    log(`[A] pulling delta since ${push1.body.server_time}`);
    const pull2 = await request('GET', `/sync/things?since=${push1.body.server_time}`);
    if (pull2.body.rows.length !== 1 || pull2.body.rows[0].name !== 'Pineapple') {
      throw new Error('A delta pull unexpected: ' + JSON.stringify(pull2.body));
    }
    log('[A] saw rename from B');

    // ── Stale-write rejection: A pushes an update with old updated_at ─
    log('[A] attempting stale write (updated_at < server)');
    const push3 = await request('POST', '/sync/things', {
      changes: [
        {
          operation: 'update',
          payload: {
            id,
            created_at: t0,
            updated_at: t0, // older than t1 already on server
            deleted_at: null,
            is_synced: 0,
            sync_status: 'pending',
            name: 'Apricot (stale)',
          },
        },
      ],
    });
    const stale = push3.body.results[0];
    if (stale.status !== 'rejected' || stale.reason !== 'stale_updated_at') {
      throw new Error('A stale write should have been rejected: ' + JSON.stringify(stale));
    }
    log('[A] stale write rejected correctly:', stale.reason);

    // ── Soft delete from A ───────────────────────────────────────────
    const t2 = Date.now() + 2000;
    log('[A] soft-deleting');
    const push4 = await request('POST', '/sync/things', {
      changes: [{ operation: 'delete', payload: { id, deleted_at: t2 } }],
    });
    if (push4.body.results[0].status !== 'ok') {
      throw new Error('A delete failed: ' + JSON.stringify(push4.body));
    }

    // ── B pulls again, sees the tombstone ────────────────────────────
    log(`[B] pulling delta since ${lastSyncB}`);
    const pull3 = await request('GET', `/sync/things?since=${lastSyncB}`);
    const tombstone = pull3.body.rows.find((r) => r.id === id);
    if (!tombstone || tombstone.deleted_at == null) {
      throw new Error('B should have seen tombstone: ' + JSON.stringify(pull3.body));
    }
    log('[B] saw soft-delete; deleted_at =', tombstone.deleted_at);

    log('✅ smoke test passed');
  } finally {
    server.close();
  }
}

main().catch((e) => {
  console.error('❌ smoke test failed:', e);
  process.exit(1);
});
