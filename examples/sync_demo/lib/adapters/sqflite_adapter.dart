import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:sqflite/sqflite.dart';

/// **Demo-grade** sqflite-backed implementation of `LocalDatabaseAdapter`.
///
/// This is NOT the production `flutter_universal_sync_sqflite` package
/// (Plan 4) — it lives in the example to demonstrate the contract end-to-end.
/// When the official adapter ships, replace this file with a dependency
/// on that package.
class SqfliteSyncAdapter implements LocalDatabaseAdapter {
  SqfliteSyncAdapter({required this.dbPath});

  final String dbPath;
  Database? _db;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('SqfliteSyncAdapter not initialised — call init() first');
    }
    return db;
  }

  @override
  Future<void> init() async {
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE things (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            is_synced INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT NOT NULL PRIMARY KEY,
            table_name TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            synced INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER
          )
        ''');
        await db.execute(
          'CREATE TABLE sync_state (table_name TEXT PRIMARY KEY NOT NULL, last_sync INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE ${SyncMetaColumns.tableName} '
          '(${SyncMetaColumns.key} TEXT PRIMARY KEY NOT NULL, '
          '${SyncMetaColumns.value} TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX queue_synced ON sync_queue(synced)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 0.1.0 → 0.2.0 engine-support migration (spec §4).
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE sync_queue ADD COLUMN next_retry_at INTEGER',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS ${SyncMetaColumns.tableName} '
            '(${SyncMetaColumns.key} TEXT PRIMARY KEY NOT NULL, '
            '${SyncMetaColumns.value} TEXT NOT NULL)',
          );
        }
      },
    );
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    await _database.insert(
      table,
      _encodeForRow(data),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final rows = await _database.update(
      table,
      _encodeForRow(data),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows == 0) {
      throw StateError('Row $id not found in $table');
    }
  }

  @override
  Future<void> delete(String table, String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rows = await _database.update(
      table,
      {'deleted_at': now, 'updated_at': now, 'is_synced': 0, 'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows == 0) {
      throw StateError('Row $id not found in $table');
    }
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    await _database.insert(
      table,
      _encodeForRow(data),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final rows = await _database.query(
      table,
      where: 'id = ?',
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
        ? await _database.query(table)
        : await _database.query(table, where: 'deleted_at IS NULL');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    await _database.insert(
      'sync_queue',
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
        'next_retry_at': entry.nextRetryAt?.toUtc().millisecondsSinceEpoch,
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
      where = 'synced = 0 AND (next_retry_at IS NULL OR next_retry_at <= ?)';
      whereArgs = [readyAt.toUtc().millisecondsSinceEpoch];
    }
    final rows = await _database.query(
      'sync_queue',
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
    final rows = await _database.query(
      'sync_queue',
      where: 'synced = 0 AND table_name = ? AND entity_id = ?',
      whereArgs: [table, entityId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_queueFromRow).toList();
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
        nextRetryAt: r['next_retry_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                r['next_retry_at'] as int,
                isUtc: true,
              ),
      );

  @override
  Future<void> markSynced(String queueEntryId) async {
    final rows = await _database.update(
      'sync_queue',
      {'synced': 1, 'last_error': null},
      where: 'id = ?',
      whereArgs: [queueEntryId],
    );
    if (rows == 0) {
      throw StateError('Queue entry $queueEntryId not found');
    }
  }

  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final setClauses = <String>[
      'last_error = ?',
      'next_retry_at = ?',
    ];
    final args = <Object?>[
      error,
      nextRetryAt?.toUtc().millisecondsSinceEpoch,
    ];
    if (incrementRetryCount) {
      setClauses.add('retry_count = retry_count + 1');
    }
    // Use rawUpdate so retry_count can reference its own column.
    final rows = await _database.rawUpdate(
      'UPDATE sync_queue SET ${setClauses.join(', ')} WHERE id = ?',
      [...args, queueEntryId],
    );
    if (rows == 0) {
      throw StateError('Queue entry $queueEntryId not found');
    }
  }

  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final rows = await _database.update(
      'sync_queue',
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [entryId],
    );
    if (rows == 0) {
      throw StateError('Queue entry $entryId not found');
    }
  }

  @override
  Future<String?> getMeta(String key) async {
    final rows = await _database.query(
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
    await _database.insert(
      SyncMetaColumns.tableName,
      {SyncMetaColumns.key: key, SyncMetaColumns.value: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteMeta(String key) async {
    await _database.delete(
      SyncMetaColumns.tableName,
      where: '${SyncMetaColumns.key} = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    return _database.transaction<T>((_) => action());
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final cols = await _database.rawQuery('PRAGMA table_info($table)');
      final declared = cols.map((c) => c['name'] as String).toSet();
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(
          table: table,
          missingColumns: missing,
        );
      }
    }
  }

  // ── demo extras: per-table lastSync persistence ─────────────────────

  /// Returns the last-sync timestamp for [table], or null if never synced.
  Future<DateTime?> lastSync(String table) async {
    final rows = await _database.query(
      'sync_state',
      where: 'table_name = ?',
      whereArgs: [table],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.first['last_sync'] as int,
      isUtc: true,
    );
  }

  /// Persists [time] as the last-sync watermark for [table].
  Future<void> setLastSync(String table, DateTime time) async {
    await _database.insert(
      'sync_state',
      {
        'table_name': table,
        'last_sync': time.toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
