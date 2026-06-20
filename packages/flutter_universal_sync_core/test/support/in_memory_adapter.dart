import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// An in-memory [LocalDatabaseAdapter] used to exercise the contract suite.
///
/// Storage shape:
///   _tables:  tableName -> rowId -> row map
///   _schemas: tableName -> set of column names (registered via
///             [registerTable] in tests before `validateSchema` is called)
///   _queue:   insertion-ordered list of queue entries
class InMemoryAdapter implements LocalDatabaseAdapter {
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  final Map<String, Set<String>> _schemas = {};
  final List<SyncQueueEntry> _queue = [];

  /// Registers [columns] as the schema for [table]. Tests call this
  /// before [validateSchema] to simulate user-declared tables.
  void registerTable(String table, Iterable<String> columns) {
    _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    _schemas[table] = columns.toSet();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final rows = _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    final id = data[SyncColumns.id] as String;
    if (rows.containsKey(id)) {
      throw StateError('Row $id already exists in $table');
    }
    rows[id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    final rows = _tables[table];
    if (rows == null || !rows.containsKey(id)) {
      throw StateError('Row $id not found in $table');
    }
    rows[id]!.addAll(data);
  }

  @override
  Future<void> delete(String table, String id) async {
    final rows = _tables[table];
    if (rows == null || !rows.containsKey(id)) {
      throw StateError('Row $id not found in $table');
    }
    rows[id]![SyncColumns.deletedAt] =
        DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final rows =
        _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    final id = data[SyncColumns.id] as String;
    if (rows.containsKey(id)) {
      rows[id]!.addAll(data);
    } else {
      rows[id] = Map<String, dynamic>.from(data);
    }
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final row = _tables[table]?[id];
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final rows = _tables[table]?.values.toList() ?? <Map<String, dynamic>>[];
    final iter = includeDeleted
        ? rows
        : rows.where((r) => r[SyncColumns.deletedAt] == null);
    return iter.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    _queue.add(entry);
  }

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit}) async {
    final pending = _queue.where((e) => !e.synced).toList();
    if (limit == null || limit >= pending.length) return pending;
    return pending.sublist(0, limit);
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final i = _queue.indexWhere((e) => e.id == queueEntryId);
    if (i < 0) throw StateError('Queue entry $queueEntryId not found');
    _queue[i] = _queue[i].copyWith(synced: true);
  }

  @override
  Future<void> recordSyncFailure(String queueEntryId, String error) async {
    final i = _queue.indexWhere((e) => e.id == queueEntryId);
    if (i < 0) throw StateError('Queue entry $queueEntryId not found');
    _queue[i] = _queue[i].copyWith(lastError: error);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    // Snapshot for rollback on throw.
    final tablesSnapshot = <String, Map<String, Map<String, dynamic>>>{
      for (final entry in _tables.entries)
        entry.key: {
          for (final row in entry.value.entries)
            row.key: _deepCopyRow(row.value),
        },
    };
    final queueSnapshot = List<SyncQueueEntry>.from(_queue);
    try {
      return await action();
    } catch (_) {
      _tables
        ..clear()
        ..addAll(tablesSnapshot);
      _queue
        ..clear()
        ..addAll(queueSnapshot);
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
        throw SchemaValidationException(
          table: table,
          missingColumns: missing,
        );
      }
    }
  }
}

Map<String, dynamic> _deepCopyRow(Map<String, dynamic> row) =>
    row.map((k, v) => MapEntry(k, _deepCopyValue(v)));

Object? _deepCopyValue(Object? value) {
  if (value is Map<String, dynamic>) return _deepCopyRow(value);
  if (value is List) return value.map(_deepCopyValue).toList();
  return value;
}
