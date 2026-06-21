/// Canonical column names every user-defined synced table must include.
///
/// Users own their local schemas (adapters do not auto-create tables);
/// `LocalDatabaseAdapter.validateSchema` is called at init to confirm
/// each column exists. Adapters for NoSQL stores (Hive, ObjectBox)
/// translate these to their native shape but must honor the names.
class SyncColumns {
  SyncColumns._();

  /// Primary key — `TEXT NOT NULL PRIMARY KEY`, UUIDv4.
  static const id = 'id';

  /// Wall-clock creation time, `INTEGER NOT NULL` millisSinceEpoch UTC.
  static const createdAt = 'created_at';

  /// Wall-clock last-update time, `INTEGER NOT NULL` millisSinceEpoch UTC.
  static const updatedAt = 'updated_at';

  /// Soft-delete timestamp, `INTEGER` nullable; millisSinceEpoch UTC.
  static const deletedAt = 'deleted_at';

  /// Acknowledged-by-server flag, `INTEGER NOT NULL DEFAULT 0`.
  static const isSynced = 'is_synced';

  /// Lifecycle status name, `TEXT NOT NULL DEFAULT 'pending'`.
  static const syncStatus = 'sync_status';

  /// Backoff timestamp on the sync queue table, `INTEGER` nullable;
  /// millisSinceEpoch UTC. NULL means "eligible immediately".
  static const nextRetryAt = 'next_retry_at';

  /// Every column name a synced table must include, in canonical order.
  static const required = <String>[
    id,
    createdAt,
    updatedAt,
    deletedAt,
    isSynced,
    syncStatus,
  ];

  /// Non-prescriptive reference SQL types for SQL-shaped adapters.
  /// NoSQL adapters translate to native shapes.
  static const Map<String, String> types = {
    id: 'TEXT NOT NULL PRIMARY KEY',
    createdAt: 'INTEGER NOT NULL',
    updatedAt: 'INTEGER NOT NULL',
    deletedAt: 'INTEGER',
    isSynced: 'INTEGER NOT NULL DEFAULT 0',
    syncStatus: "TEXT NOT NULL DEFAULT 'pending'",
  };

  /// Reference SQL types for the engine's sync queue table. Domain
  /// tables use [types]; the queue-internal columns live here so we
  /// don't pollute the per-row schema contract that user tables share.
  static const Map<String, String> queueTypes = {
    nextRetryAt: 'INTEGER',
  };
}

/// Canonical column names for the engine's generic key/value state table.
///
/// Adapters must create this table at init time. The engine writes
/// per-table pull cursors here today; future engine state (device id,
/// schema version, last-drain timestamp) goes here too.
class SyncMetaColumns {
  SyncMetaColumns._();

  /// The KV table's name. Underscore prefix marks it as engine-owned.
  static const tableName = '_sync_meta';

  /// `TEXT NOT NULL PRIMARY KEY` — engine-defined namespaced key.
  static const key = 'key';

  /// `TEXT NOT NULL` — opaque to adapters; engine encodes as needed.
  static const value = 'value';

  /// Every column the meta table must include, in canonical order.
  static const required = <String>[key, value];

  /// Reference SQL types for SQL-shaped adapters.
  static const Map<String, String> types = {
    key: 'TEXT NOT NULL PRIMARY KEY',
    value: 'TEXT NOT NULL',
  };
}
