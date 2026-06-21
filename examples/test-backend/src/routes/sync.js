const express = require('express');
const {
  db,
  isAllowedTable,
  tableSpec,
  columnsFor,
} = require('../db');

const router = express.Router();

/**
 * GET /sync/:table?since=<millisSinceEpoch>
 *
 * Returns rows whose `updated_at` OR `deleted_at` is strictly greater than
 * the supplied `since`. With no `since`, returns every row.
 *
 * Response: { rows: [...], server_time: <ms> }
 */
router.get('/:table', (req, res) => {
  const { table } = req.params;
  if (!isAllowedTable(table)) {
    return res.status(404).json({ error: `Unknown table: ${table}` });
  }

  const sinceRaw = req.query.since;
  const since = sinceRaw == null || sinceRaw === '' ? null : Number(sinceRaw);

  if (since != null && Number.isNaN(since)) {
    return res.status(400).json({ error: '`since` must be a number (ms)' });
  }

  let rows;
  if (since == null) {
    rows = db.prepare(`SELECT * FROM ${table}`).all();
  } else {
    rows = db
      .prepare(
        `SELECT * FROM ${table} WHERE updated_at > ? OR deleted_at > ?`,
      )
      .all(since, since);
  }

  res.json({ rows, server_time: Date.now() });
});

/**
 * POST /sync/:table
 *
 * Body: {
 *   changes: [
 *     { operation: 'insert' | 'update' | 'delete', payload: { id, ...row } }
 *   ]
 * }
 *
 * Semantics:
 * - `insert` / `update` upsert the row. Conflict resolution is server-side
 *   last-write-wins by `updated_at`: incoming row wins iff its updated_at
 *   is >= the stored row's updated_at.
 * - `delete` is soft delete: sets deleted_at to server time. The row stays
 *   so the deletion can propagate to other clients via pull.
 *
 * Each entry returns one of:
 *   { id, status: 'ok' }
 *   { id, status: 'rejected', reason: 'stale_updated_at' }
 *   { id, status: 'error',    reason: '...' }
 */
router.post('/:table', (req, res) => {
  const { table } = req.params;
  if (!isAllowedTable(table)) {
    return res.status(404).json({ error: `Unknown table: ${table}` });
  }

  const changes = Array.isArray(req.body?.changes) ? req.body.changes : null;
  if (!changes) {
    return res
      .status(400)
      .json({ error: 'Body must include a `changes` array' });
  }

  const spec = tableSpec(table);
  const knownColumns = new Set(columnsFor(table));
  const userColumns = Object.keys(spec.extraColumns);

  const results = [];
  const now = Date.now();

  // Build dynamic upsert / delete statements.
  const placeholders = [...knownColumns]
    .map((c) => `@${c}`)
    .join(', ');
  const setClause = userColumns
    .concat(['deleted_at'])
    .map((c) => `${c} = excluded.${c}`)
    .join(', ');

  const upsert = db.prepare(`
    INSERT INTO ${table} (${[...knownColumns].join(', ')})
    VALUES (${placeholders})
    ON CONFLICT(id) DO UPDATE SET
      updated_at = excluded.updated_at,
      ${setClause},
      is_synced = 1,
      sync_status = 'synced'
    WHERE excluded.updated_at >= ${table}.updated_at
  `);

  const softDelete = db.prepare(`
    UPDATE ${table}
       SET deleted_at = @deleted_at,
           updated_at = @updated_at,
           is_synced = 1,
           sync_status = 'synced'
     WHERE id = @id
       AND (@updated_at >= ${table}.updated_at OR ${table}.deleted_at IS NULL)
  `);

  const fetchOne = db.prepare(`SELECT id, updated_at FROM ${table} WHERE id = ?`);

  const tx = db.transaction((items) => {
    for (const change of items) {
      const op = change?.operation;
      const payload = change?.payload;

      if (!op || !payload || typeof payload.id !== 'string') {
        results.push({
          id: payload?.id ?? null,
          status: 'error',
          reason: 'missing_operation_or_payload_id',
        });
        continue;
      }

      try {
        if (op === 'delete') {
          const ts = payload.deleted_at ?? now;
          const info = softDelete.run({
            id: payload.id,
            deleted_at: ts,
            updated_at: ts,
          });
          if (info.changes === 0) {
            // Row didn't exist, or stored updated_at is newer — surface stale
            const existing = fetchOne.get(payload.id);
            if (!existing) {
              // Treat delete-of-nonexistent as success (idempotent).
              results.push({ id: payload.id, status: 'ok', note: 'no_op_unknown_id' });
            } else {
              results.push({
                id: payload.id,
                status: 'rejected',
                reason: 'stale_updated_at',
              });
            }
          } else {
            results.push({ id: payload.id, status: 'ok' });
          }
          continue;
        }

        // insert / update — both upsert with LWW
        const row = {};
        for (const col of knownColumns) {
          if (col === 'id') row.id = payload.id;
          else if (col === 'created_at')
            row.created_at = payload.created_at ?? now;
          else if (col === 'updated_at')
            row.updated_at = payload.updated_at ?? now;
          else if (col === 'deleted_at')
            row.deleted_at = payload.deleted_at ?? null;
          else if (col === 'is_synced') row.is_synced = 1;
          else if (col === 'sync_status') row.sync_status = 'synced';
          else row[col] = payload[col] ?? null;
        }

        const info = upsert.run(row);

        // SQLite's INSERT...ON CONFLICT...DO UPDATE WHERE: when WHERE prunes
        // the UPDATE, info.changes is 0 even though the row exists. Detect
        // that by checking whether the row in the DB still has its prior
        // updated_at.
        if (info.changes === 0) {
          const existing = fetchOne.get(payload.id);
          if (existing && existing.updated_at > row.updated_at) {
            results.push({
              id: payload.id,
              status: 'rejected',
              reason: 'stale_updated_at',
              server_updated_at: existing.updated_at,
            });
          } else {
            // Genuine no-op (e.g. duplicate insert with identical updated_at).
            results.push({ id: payload.id, status: 'ok' });
          }
        } else {
          results.push({ id: payload.id, status: 'ok' });
        }
      } catch (e) {
        results.push({
          id: payload.id,
          status: 'error',
          reason: e.message,
        });
      }
    }
  });

  tx(changes);
  res.json({ results, server_time: now });
});

module.exports = router;
