import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Minimal drift database with no declared tables — the adapter drives it
/// entirely through raw SQL (`customStatement` / `customSelect`).
class _RawDb extends GeneratedDatabase {
  _RawDb(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// A drift-backed [LocalDatabaseAdapter].
///
/// Pure Dart: the [QueryExecutor] is injected, so the adapter runs under
/// Flutter (your drift `NativeDatabase`/`LazyDatabase`) and under the Dart
/// VM in tests (`NativeDatabase.memory()`). It uses no generated code —
/// every operation is raw SQL on a private [GeneratedDatabase].
///
/// Owns two internal tables, created on [init]: `sync_queue` (with
/// `next_retry_at` backoff) and `_sync_meta` (engine KV). You own your
/// domain tables; create them via [database] and call [validateSchema].
class DriftSyncAdapter implements LocalDatabaseAdapter {
  /// Creates an adapter over [executor] (e.g. `NativeDatabase.memory()`).
  DriftSyncAdapter({required this.executor});

  /// The drift query executor the database is opened on.
  final QueryExecutor executor;

  static const _queueTable = 'sync_queue';

  _RawDb? _db;

  /// The opened database. Throws if [init] has not run. Exposed so apps
  /// can create their domain tables and tests can run DDL.
  GeneratedDatabase get database {
    final db = _db;
    if (db == null) {
      throw StateError('DriftSyncAdapter not initialised — call init() first');
    }
    return db;
  }

  @override
  Future<void> init() async {
    final db = _RawDb(executor);
    _db = db;
    await db.customStatement('''
      CREATE TABLE $_queueTable (
        id TEXT NOT NULL PRIMARY KEY,
        table_name TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        ${SyncColumns.nextRetryAt} INTEGER
      )
    ''');
    await db.customStatement(
      'CREATE TABLE ${SyncMetaColumns.tableName} '
      '(${SyncMetaColumns.key} TEXT PRIMARY KEY NOT NULL, '
      '${SyncMetaColumns.value} TEXT NOT NULL)',
    );
    await db
        .customStatement('CREATE INDEX queue_synced ON $_queueTable(synced)');
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final enc = _encodeForRow(data);
    final cols = enc.keys.toList();
    final sql = 'INSERT INTO $table (${cols.join(', ')}) '
        'VALUES (${List.filled(cols.length, '?').join(', ')})';
    try {
      await database.customInsert(
        sql,
        variables: [for (final c in cols) Variable<Object>(enc[c])],
      );
    } on Object catch (e) {
      if (_isUniqueViolation(e)) {
        throw StateError(
            'Row ${data[SyncColumns.id]} already exists in $table');
      }
      rethrow;
    }
  }

  @override
  Future<void> update(
      String table, String id, Map<String, dynamic> data) async {
    final enc = _encodeForRow(data);
    final cols = enc.keys.toList();
    final assignments = cols.map((c) => '$c = ?').join(', ');
    final affected = await database.customUpdate(
      'UPDATE $table SET $assignments WHERE ${SyncColumns.id} = ?',
      variables: [
        for (final c in cols) Variable<Object>(enc[c]),
        Variable<String>(id),
      ],
      updateKind: UpdateKind.update,
    );
    if (affected == 0) throw StateError('Row $id not found in $table');
  }

  @override
  Future<void> delete(String table, String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final affected = await database.customUpdate(
      'UPDATE $table SET ${SyncColumns.deletedAt} = ?, '
      '${SyncColumns.updatedAt} = ?, ${SyncColumns.isSynced} = 0, '
      "${SyncColumns.syncStatus} = 'pending' WHERE ${SyncColumns.id} = ?",
      variables: [Variable<int>(now), Variable<int>(now), Variable<String>(id)],
      updateKind: UpdateKind.update,
    );
    if (affected == 0) throw StateError('Row $id not found in $table');
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final enc = _encodeForRow(data);
    final cols = enc.keys.toList();
    final sql = 'INSERT OR REPLACE INTO $table (${cols.join(', ')}) '
        'VALUES (${List.filled(cols.length, '?').join(', ')})';
    await database.customInsert(
      sql,
      variables: [for (final c in cols) Variable<Object>(enc[c])],
    );
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final rows = await database.customSelect(
      'SELECT * FROM $table WHERE ${SyncColumns.id} = ? LIMIT 1',
      variables: [Variable<String>(id)],
    ).get();
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final sql = includeDeleted
        ? 'SELECT * FROM $table'
        : 'SELECT * FROM $table WHERE ${SyncColumns.deletedAt} IS NULL';
    final rows = await database.customSelect(sql).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    await database.customInsert(
      'INSERT INTO $_queueTable (id, table_name, entity_id, operation, '
      'payload, created_at, retry_count, last_error, synced, '
      '${SyncColumns.nextRetryAt}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(entry.id),
        Variable<String>(entry.table),
        Variable<String>(entry.entityId),
        Variable<String>(entry.operation.name),
        Variable<String>(jsonEncode(entry.payload)),
        Variable<int>(entry.createdAt.toUtc().millisecondsSinceEpoch),
        Variable<int>(entry.retryCount),
        Variable<String>(entry.lastError),
        Variable<int>(entry.synced ? 1 : 0),
        Variable<int>(entry.nextRetryAt?.toUtc().millisecondsSinceEpoch),
      ],
    );
  }

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  }) async {
    final where = readyAt == null
        ? 'synced = 0'
        : 'synced = 0 AND (${SyncColumns.nextRetryAt} IS NULL OR '
            '${SyncColumns.nextRetryAt} <= ?)';
    final sql = 'SELECT * FROM $_queueTable WHERE $where '
        'ORDER BY created_at ASC${limit == null ? '' : ' LIMIT ?'}';
    final rows = await database.customSelect(
      sql,
      variables: [
        if (readyAt != null)
          Variable<int>(readyAt.toUtc().millisecondsSinceEpoch),
        if (limit != null) Variable<int>(limit),
      ],
    ).get();
    return rows.map((r) => _queueFromRow(r.data)).toList();
  }

  @override
  Future<List<SyncQueueEntry>> pendingForEntity(
    String table,
    String entityId,
  ) async {
    final rows = await database.customSelect(
      'SELECT * FROM $_queueTable WHERE synced = 0 AND table_name = ? '
      'AND entity_id = ? ORDER BY created_at ASC',
      variables: [Variable<String>(table), Variable<String>(entityId)],
    ).get();
    return rows.map((r) => _queueFromRow(r.data)).toList();
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final affected = await database.customUpdate(
      'UPDATE $_queueTable SET synced = 1, last_error = NULL WHERE id = ?',
      variables: [Variable<String>(queueEntryId)],
      updateKind: UpdateKind.update,
    );
    if (affected == 0) throw StateError('Queue entry $queueEntryId not found');
  }

  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final retryClause =
        incrementRetryCount ? ', retry_count = retry_count + 1' : '';
    final affected = await database.customUpdate(
      'UPDATE $_queueTable SET last_error = ?, '
      '${SyncColumns.nextRetryAt} = ?$retryClause WHERE id = ?',
      variables: [
        Variable<String>(error),
        Variable<int>(nextRetryAt?.toUtc().millisecondsSinceEpoch),
        Variable<String>(queueEntryId),
      ],
      updateKind: UpdateKind.update,
    );
    if (affected == 0) throw StateError('Queue entry $queueEntryId not found');
  }

  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final affected = await database.customUpdate(
      'UPDATE $_queueTable SET payload = ? WHERE id = ?',
      variables: [
        Variable<String>(jsonEncode(payload)),
        Variable<String>(entryId)
      ],
      updateKind: UpdateKind.update,
    );
    if (affected == 0) throw StateError('Queue entry $entryId not found');
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = await database.customSelect(
      'SELECT ${SyncMetaColumns.value} FROM ${SyncMetaColumns.tableName} '
      'WHERE ${SyncMetaColumns.key} = ? LIMIT 1',
      variables: [Variable<String>(key)],
    ).get();
    return rows.isEmpty
        ? null
        : rows.first.data[SyncMetaColumns.value] as String;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    await database.customInsert(
      'INSERT OR REPLACE INTO ${SyncMetaColumns.tableName} '
      '(${SyncMetaColumns.key}, ${SyncMetaColumns.value}) VALUES (?, ?)',
      variables: [Variable<String>(key), Variable<String>(value)],
    );
  }

  @override
  Future<void> deleteMeta(String key) async {
    await database.customUpdate(
      'DELETE FROM ${SyncMetaColumns.tableName} WHERE ${SyncMetaColumns.key} = ?',
      variables: [Variable<String>(key)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) {
    // drift runs the callback in a zone where customStatement/customSelect
    // use the transaction executor, and rolls back if it throws.
    return database.transaction(action);
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final cols =
          await database.customSelect('PRAGMA table_info($table)').get();
      final declared = cols.map((c) => c.data['name'] as String).toSet();
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(table: table, missingColumns: missing);
      }
    }
  }

  bool _isUniqueViolation(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('unique') || s.contains('primary key');
  }

  SyncQueueEntry _queueFromRow(Map<String, dynamic> r) => SyncQueueEntry(
        id: r['id'] as String,
        table: r['table_name'] as String,
        entityId: r['entity_id'] as String,
        operation: SyncOperation.values.byName(r['operation'] as String),
        payload: Map<String, dynamic>.from(
          jsonDecode(r['payload'] as String) as Map,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          r['created_at'] as int,
          isUtc: true,
        ),
        retryCount: r['retry_count'] as int? ?? 0,
        lastError: r['last_error'] as String?,
        synced: (r['synced'] as int? ?? 0) == 1,
        nextRetryAt: r[SyncColumns.nextRetryAt] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                r[SyncColumns.nextRetryAt] as int,
                isUtc: true,
              ),
      );

  Map<String, Object?> _encodeForRow(Map<String, dynamic> data) {
    final out = <String, Object?>{};
    for (final entry in data.entries) {
      final v = entry.value;
      if (v == null || v is num || v is String) {
        out[entry.key] = v;
      } else if (v is bool) {
        out[entry.key] = v ? 1 : 0;
      } else if (v is DateTime) {
        out[entry.key] = v.toUtc().millisecondsSinceEpoch;
      } else {
        out[entry.key] = jsonEncode(v);
      }
    }
    return out;
  }
}
