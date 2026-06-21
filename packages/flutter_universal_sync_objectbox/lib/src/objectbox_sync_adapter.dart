import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:objectbox/objectbox.dart';

import '../objectbox.g.dart';
import 'sync_record.dart';

/// An ObjectBox-backed [LocalDatabaseAdapter].
///
/// ObjectBox is strongly typed, so every stored fact — domain rows, queue
/// entries, meta KV pairs — lives in one generic [SyncRecord] entity keyed
/// by `kind`. The adapter satisfies the contract by querying SyncRecords.
///
/// > **Build note:** this package requires generated bindings
/// > (`objectbox.g.dart`, via `dart run build_runner build`) and the
/// > ObjectBox native library. See the README. It mirrors the logic of the
/// > verified in-memory / Hive adapters.
class ObjectboxSyncAdapter implements LocalDatabaseAdapter {
  /// Creates an adapter whose store lives under [directory].
  ObjectboxSyncAdapter({required this.directory});

  /// Filesystem directory the ObjectBox store opens in.
  final String directory;

  final Map<String, Set<String>> _schemas = {};
  Store? _store;
  bool _inTxn = false;

  Box<SyncRecord> get _box => _store!.box<SyncRecord>();

  /// Registers [columns] as the schema for [table] (used by
  /// [validateSchema]). The contract suite calls this before validating.
  void registerTable(String table, Iterable<String> columns) {
    _schemas[table] = columns.toSet();
  }

  @override
  Future<void> init() async {
    _store = Store(getObjectBoxModel(), directory: directory);
  }

  @override
  Future<void> close() async {
    _store?.close();
    _store = null;
  }

  SyncRecord? _rowRec(String table, String id) => _box
      .query(
        SyncRecord_.kind.equals('row') &
            SyncRecord_.table.equals(table) &
            SyncRecord_.key.equals(id),
      )
      .build()
      .findFirst();

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final id = data[SyncColumns.id] as String;
    if (_rowRec(table, id) != null) {
      throw StateError('Row $id already exists in $table');
    }
    _box.put(
      SyncRecord(kind: 'row', table: table, key: id, dataJson: jsonEncode(data)),
    );
  }

  @override
  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    final rec = _rowRec(table, id);
    if (rec == null) throw StateError('Row $id not found in $table');
    final row = _decode(rec.dataJson)..addAll(data);
    _box.put(rec..dataJson = jsonEncode(row));
  }

  @override
  Future<void> delete(String table, String id) async {
    final rec = _rowRec(table, id);
    if (rec == null) throw StateError('Row $id not found in $table');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final row = _decode(rec.dataJson)
      ..[SyncColumns.deletedAt] = now
      ..[SyncColumns.updatedAt] = now
      ..[SyncColumns.isSynced] = 0
      ..[SyncColumns.syncStatus] = 'pending';
    _box.put(rec..dataJson = jsonEncode(row));
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final id = data[SyncColumns.id] as String;
    final rec = _rowRec(table, id);
    if (rec == null) {
      _box.put(
        SyncRecord(
          kind: 'row',
          table: table,
          key: id,
          dataJson: jsonEncode(data),
        ),
      );
    } else {
      final row = _decode(rec.dataJson)..addAll(data);
      _box.put(rec..dataJson = jsonEncode(row));
    }
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final rec = _rowRec(table, id);
    return rec == null ? null : _decode(rec.dataJson);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final recs = _box
        .query(SyncRecord_.kind.equals('row') & SyncRecord_.table.equals(table))
        .build()
        .find();
    final rows = recs.map((r) => _decode(r.dataJson));
    final iter = includeDeleted
        ? rows
        : rows.where((r) => r[SyncColumns.deletedAt] == null);
    return iter.toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    _box.put(
      SyncRecord(
        kind: 'queue',
        table: entry.table,
        key: entry.id,
        entityId: entry.entityId,
        dataJson: jsonEncode(entry.payload),
        synced: entry.synced,
        createdAt: entry.createdAt.toUtc().millisecondsSinceEpoch,
        retryCount: entry.retryCount,
        lastError: entry.lastError,
        operation: entry.operation.name,
        nextRetryAt: entry.nextRetryAt?.toUtc().millisecondsSinceEpoch,
      ),
    );
  }

  SyncRecord? _queueRec(String id) => _box
      .query(SyncRecord_.kind.equals('queue') & SyncRecord_.key.equals(id))
      .build()
      .findFirst();

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  }) async {
    final q = _box.query(
      SyncRecord_.kind.equals('queue') & SyncRecord_.synced.equals(false),
    )..order(SyncRecord_.obxId);
    final built = q.build();
    var recs = built.find();
    built.close();
    if (readyAt != null) {
      final t = readyAt.toUtc().millisecondsSinceEpoch;
      recs = recs.where((r) => r.nextRetryAt == null || r.nextRetryAt! <= t)
          .toList();
    }
    final entries = recs.map(_toEntry).toList();
    if (limit == null || limit >= entries.length) return entries;
    return entries.sublist(0, limit);
  }

  @override
  Future<List<SyncQueueEntry>> pendingForEntity(
    String table,
    String entityId,
  ) async {
    final built = _box.query(
      SyncRecord_.kind.equals('queue') &
          SyncRecord_.synced.equals(false) &
          SyncRecord_.table.equals(table) &
          SyncRecord_.entityId.equals(entityId),
    ).build()
      ..order(SyncRecord_.createdAt);
    final recs = built.find();
    built.close();
    return recs.map(_toEntry).toList();
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final rec = _queueRec(queueEntryId);
    if (rec == null) throw StateError('Queue entry $queueEntryId not found');
    _box.put(rec
      ..synced = true
      ..lastError = null);
  }

  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final rec = _queueRec(queueEntryId);
    if (rec == null) throw StateError('Queue entry $queueEntryId not found');
    _box.put(rec
      ..lastError = error
      ..retryCount = incrementRetryCount ? rec.retryCount + 1 : rec.retryCount
      ..nextRetryAt = nextRetryAt?.toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final rec = _queueRec(entryId);
    if (rec == null) throw StateError('Queue entry $entryId not found');
    _box.put(rec..dataJson = jsonEncode(payload));
  }

  @override
  Future<String?> getMeta(String key) async {
    final rec = _box
        .query(SyncRecord_.kind.equals('meta') & SyncRecord_.key.equals(key))
        .build()
        .findFirst();
    return rec?.dataJson;
  }

  @override
  Future<void> setMeta(String key, String value) async {
    final rec = _box
        .query(SyncRecord_.kind.equals('meta') & SyncRecord_.key.equals(key))
        .build()
        .findFirst();
    if (rec == null) {
      _box.put(SyncRecord(kind: 'meta', key: key, dataJson: value));
    } else {
      _box.put(rec..dataJson = value);
    }
  }

  @override
  Future<void> deleteMeta(String key) async {
    final built = _box
        .query(SyncRecord_.kind.equals('meta') & SyncRecord_.key.equals(key))
        .build();
    built.remove();
    built.close();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    if (_inTxn) return action();
    _inTxn = true;
    final snapshot = _box.getAll();
    try {
      final result = await action();
      _inTxn = false;
      return result;
    } catch (_) {
      _box.removeAll();
      _box.putMany(snapshot);
      _inTxn = false;
      rethrow;
    }
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final declared = _schemas[table] ?? const <String>{};
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(table: table, missingColumns: missing);
      }
    }
  }

  SyncQueueEntry _toEntry(SyncRecord r) => SyncQueueEntry(
        id: r.key,
        table: r.table,
        entityId: r.entityId,
        operation: SyncOperation.values.byName(r.operation),
        payload: _decode(r.dataJson),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
        retryCount: r.retryCount,
        lastError: r.lastError,
        synced: r.synced,
        nextRetryAt: r.nextRetryAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r.nextRetryAt!, isUtc: true),
      );

  Map<String, dynamic> _decode(String s) =>
      Map<String, dynamic>.from(jsonDecode(s) as Map);
}
