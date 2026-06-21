import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// A SQLite-backed [LocalDatabaseAdapter] built on `sqflite_common`.
///
/// Pure Dart: the [DatabaseFactory] is injected, so the same adapter runs
/// under Flutter (`databaseFactory` from `package:sqflite`) and under the
/// Dart VM in tests (`databaseFactoryFfi` from `package:sqflite_common_ffi`).
///
/// The adapter owns two internal tables, created on [init]:
/// - `sync_queue` — the operation queue (with `next_retry_at` for backoff).
/// - `_sync_meta` — the engine's key/value state (pull cursors, etc.).
///
/// Domain tables (the rows you sync) are **yours** to create; the adapter
/// never creates them. Call [validateSchema] after creating them to confirm
/// they carry the required [SyncColumns].
class SqfliteSyncAdapter
    implements LocalDatabaseAdapter, PurgeableAdapter, PaginatedAdapter {
  /// Creates an adapter that opens [path] via [databaseFactory].
  ///
  /// For tests pass `databaseFactoryFfi` and
  /// `sqflite_common.inMemoryDatabasePath`. In a Flutter app pass the
  /// global `databaseFactory` from `package:sqflite` and a file path.
  SqfliteSyncAdapter({required this.databaseFactory, required this.path});

  /// Factory used to open the database.
  final DatabaseFactory databaseFactory;

  /// Database location (file path, or `inMemoryDatabasePath`).
  final String path;

  static const _queueTable = 'sync_queue';

  Database? _db;
  Transaction? _txn;

  /// The opened database. Throws if [init] has not run. Exposed so apps
  /// can create their domain tables and tests can run DDL.
  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError('SqfliteSyncAdapter not initialised — call init() first');
    }
    return db;
  }

  /// The current executor: the active transaction if one is running,
  /// otherwise the database. Lets every write participate in [transaction].
  DatabaseExecutor get _exec => _txn ?? database;

  @override
  Future<void> init() async {
    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
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
          await db.execute(
            'CREATE TABLE ${SyncMetaColumns.tableName} '
            '(${SyncMetaColumns.key} TEXT PRIMARY KEY NOT NULL, '
            '${SyncMetaColumns.value} TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX queue_synced ON $_queueTable(synced)',
          );
        },
      ),
    );
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    try {
      await _exec.insert(
        table,
        _encodeForRow(data),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      // Match the contract's StateError-on-duplicate semantics.
      if (e.isUniqueConstraintError()) {
        throw StateError('Row ${data[SyncColumns.id]} already exists in $table');
      }
      rethrow;
    }
  }

  @override
  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    final rows = await _exec.update(
      table,
      _encodeForRow(data),
      where: '${SyncColumns.id} = ?',
      whereArgs: [id],
    );
    if (rows == 0) throw StateError('Row $id not found in $table');
  }

  @override
  Future<void> delete(String table, String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rows = await _exec.update(
      table,
      {
        SyncColumns.deletedAt: now,
        SyncColumns.updatedAt: now,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      },
      where: '${SyncColumns.id} = ?',
      whereArgs: [id],
    );
    if (rows == 0) throw StateError('Row $id not found in $table');
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    await _exec.insert(
      table,
      _encodeForRow(data),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final rows = await _exec.query(
      table,
      where: '${SyncColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final rows = includeDeleted
        ? await _exec.query(table)
        : await _exec.query(table, where: '${SyncColumns.deletedAt} IS NULL');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    await _exec.insert(
      _queueTable,
      {
        'id': entry.id,
        'table_name': entry.table,
        'entity_id': entry.entityId,
        'operation': entry.operation.name,
        'payload': jsonEncode(entry.payload),
        'created_at': entry.createdAt.toUtc().millisecondsSinceEpoch,
        'retry_count': entry.retryCount,
        'last_error': entry.lastError,
        'synced': entry.synced ? 1 : 0,
        SyncColumns.nextRetryAt:
            entry.nextRetryAt?.toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  }) async {
    final String where;
    final List<Object?> whereArgs;
    if (readyAt == null) {
      where = 'synced = 0';
      whereArgs = const [];
    } else {
      where = 'synced = 0 AND '
          '(${SyncColumns.nextRetryAt} IS NULL OR ${SyncColumns.nextRetryAt} <= ?)';
      whereArgs = [readyAt.toUtc().millisecondsSinceEpoch];
    }
    final rows = await _exec.query(
      _queueTable,
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_queueFromRow).toList();
  }

  @override
  Future<List<SyncQueueEntry>> pendingForEntity(
    String table,
    String entityId,
  ) async {
    final rows = await _exec.query(
      _queueTable,
      where: 'synced = 0 AND table_name = ? AND entity_id = ?',
      whereArgs: [table, entityId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_queueFromRow).toList();
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final rows = await _exec.update(
      _queueTable,
      {'synced': 1, 'last_error': null},
      where: 'id = ?',
      whereArgs: [queueEntryId],
    );
    if (rows == 0) throw StateError('Queue entry $queueEntryId not found');
  }

  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final setClauses = <String>['last_error = ?', '${SyncColumns.nextRetryAt} = ?'];
    final args = <Object?>[error, nextRetryAt?.toUtc().millisecondsSinceEpoch];
    if (incrementRetryCount) {
      setClauses.add('retry_count = retry_count + 1');
    }
    final rows = await _exec.rawUpdate(
      'UPDATE $_queueTable SET ${setClauses.join(', ')} WHERE id = ?',
      [...args, queueEntryId],
    );
    if (rows == 0) throw StateError('Queue entry $queueEntryId not found');
  }

  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final rows = await _exec.update(
      _queueTable,
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [entryId],
    );
    if (rows == 0) throw StateError('Queue entry $entryId not found');
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = await _exec.query(
      SyncMetaColumns.tableName,
      columns: [SyncMetaColumns.value],
      where: '${SyncMetaColumns.key} = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[SyncMetaColumns.value] as String;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    await _exec.insert(
      SyncMetaColumns.tableName,
      {SyncMetaColumns.key: key, SyncMetaColumns.value: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteMeta(String key) async {
    await _exec.delete(
      SyncMetaColumns.tableName,
      where: '${SyncMetaColumns.key} = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<int> purgeSynced(
    String table, {
    DateTime? olderThan,
    int? keepLatest,
  }) async {
    if (olderThan == null && keepLatest == null) return 0;

    // Synced rows only, newest first — never purge pending (unsynced) rows.
    final synced = await _exec.query(
      table,
      where: '${SyncColumns.isSynced} = 1',
      orderBy: '${SyncColumns.updatedAt} DESC',
    );
    final protected = keepLatest == null
        ? const <String>{}
        : synced
            .take(keepLatest)
            .map((r) => r[SyncColumns.id] as String)
            .toSet();
    final cutoff = olderThan?.toUtc().millisecondsSinceEpoch;

    var removed = 0;
    for (final row in synced) {
      final id = row[SyncColumns.id] as String;
      if (protected.contains(id)) continue;
      final updatedAt = (row[SyncColumns.updatedAt] as int?) ?? 0;
      if (cutoff != null && updatedAt >= cutoff) continue;
      removed += await _exec.delete(
        table,
        where: '${SyncColumns.id} = ?',
        whereArgs: [id],
      );
    }
    return removed;
  }

  @override
  Future<PageResult> getPage(
    String table, {
    int limit = 20,
    String orderBy = SyncColumns.updatedAt,
    bool descending = true,
    PageCursor? after,
    bool includeDeleted = false,
  }) async {
    final dir = descending ? 'DESC' : 'ASC';
    final op = descending ? '<' : '>';
    final clauses = <String>[];
    final args = <Object?>[];
    if (!includeDeleted) clauses.add('${SyncColumns.deletedAt} IS NULL');
    if (after != null) {
      // Keyset seek: row sorts strictly after the cursor (value, id).
      clauses.add(
        '($orderBy $op ? OR ($orderBy = ? AND ${SyncColumns.id} $op ?))',
      );
      args
        ..add(after.value)
        ..add(after.value)
        ..add(after.id);
    }
    final rows = await _exec.query(
      table,
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '$orderBy $dir, ${SyncColumns.id} $dir',
      limit: limit,
    );
    final list = rows.map(Map<String, dynamic>.from).toList();
    final next = list.length == limit
        ? PageCursor(
            value: list.last[orderBy],
            id: list.last[SyncColumns.id] as String,
          )
        : null;
    return PageResult(rows: list, nextCursor: next);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_txn != null) {
      // Already inside a transaction — run inline (no nesting in sqflite).
      return action();
    }
    return database.transaction<T>((txn) async {
      _txn = txn;
      try {
        return await action();
      } finally {
        _txn = null;
      }
    });
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final cols = await database.rawQuery('PRAGMA table_info($table)');
      final declared = cols.map((c) => c['name'] as String).toSet();
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(table: table, missingColumns: missing);
      }
    }
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
    // sqflite accepts only num/String/null/Uint8List as bind values.
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
