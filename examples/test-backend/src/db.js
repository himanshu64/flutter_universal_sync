const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const DB_PATH =
  process.env.DB_PATH || path.join(__dirname, '..', 'data', 'sync.db');

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
db.pragma('synchronous = NORMAL');

/**
 * Sync columns every table tracked by flutter_universal_sync_core MUST
 * include. Mirrors `SyncColumns` in the Dart core package.
 */
const SYNC_COLUMNS = {
  id: 'TEXT NOT NULL PRIMARY KEY',
  created_at: 'INTEGER NOT NULL',
  updated_at: 'INTEGER NOT NULL',
  deleted_at: 'INTEGER',
  is_synced: 'INTEGER NOT NULL DEFAULT 1',
  sync_status: "TEXT NOT NULL DEFAULT 'synced'",
};

/**
 * Whitelist of tables this backend is willing to serve. Add to this list
 * (and re-run init) to support more tables.
 *
 * Each entry: { name, extraColumns: { columnName: 'TYPE NULL/NOT NULL DEFAULT ...' } }
 */
const TABLES = [
  {
    name: 'things',
    extraColumns: { name: 'TEXT' },
  },
];

function buildCreateTable(spec) {
  const columns = { ...SYNC_COLUMNS, ...spec.extraColumns };
  const lines = Object.entries(columns).map(
    ([col, def]) => `  ${col} ${def}`,
  );
  return `CREATE TABLE IF NOT EXISTS ${spec.name} (\n${lines.join(',\n')}\n);`;
}

function buildIndexes(spec) {
  return [
    `CREATE INDEX IF NOT EXISTS ${spec.name}_updated_at ON ${spec.name}(updated_at);`,
    `CREATE INDEX IF NOT EXISTS ${spec.name}_deleted_at ON ${spec.name}(deleted_at);`,
  ].join('\n');
}

function initDb() {
  for (const spec of TABLES) {
    db.exec(buildCreateTable(spec));
    db.exec(buildIndexes(spec));
  }
}

function tableSpec(name) {
  return TABLES.find((t) => t.name === name);
}

function isAllowedTable(name) {
  return Boolean(tableSpec(name));
}

function columnsFor(name) {
  const spec = tableSpec(name);
  if (!spec) return [];
  return [...Object.keys(SYNC_COLUMNS), ...Object.keys(spec.extraColumns)];
}

module.exports = { db, initDb, isAllowedTable, tableSpec, columnsFor };
