/**
 * Seed a few rows so manual GET /sync/things returns something interesting.
 * Run with: `npm run seed`
 */
const { db, initDb } = require('./db');
const { randomUUID } = require('crypto');

initDb();

const now = Date.now();
const insert = db.prepare(`
  INSERT OR REPLACE INTO things
    (id, created_at, updated_at, deleted_at, is_synced, sync_status, name)
  VALUES (?, ?, ?, NULL, 1, 'synced', ?)
`);

const seedRows = [
  { id: randomUUID(), name: 'Apple' },
  { id: randomUUID(), name: 'Banana' },
  { id: randomUUID(), name: 'Cherry' },
];

const tx = db.transaction((rows) => {
  for (const r of rows) {
    insert.run(r.id, now, now, r.name);
  }
});

tx(seedRows);

console.log(`Seeded ${seedRows.length} rows into things at ${new Date(now).toISOString()}`);
console.log('IDs:', seedRows.map((r) => r.id).join(', '));
