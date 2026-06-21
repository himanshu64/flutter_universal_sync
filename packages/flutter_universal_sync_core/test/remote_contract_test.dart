import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';

/// A minimal in-memory [RemoteSyncAdapter] — both a self-test of the contract
/// and a reference for what a correct adapter must do.
class _InMemoryRemote implements RemoteSyncAdapter {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    final table = store.putIfAbsent(entry.table, () => {});
    switch (entry.operation) {
      case SyncOperation.insert:
      case SyncOperation.update:
        table[entry.entityId] = Map<String, dynamic>.from(entry.payload);
      case SyncOperation.delete:
        table.remove(entry.entityId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    final rows = store[table]
            ?.values
            .map((r) => Map<String, dynamic>.from(r))
            .toList() ??
        <Map<String, dynamic>>[];
    if (since == null) return rows;
    final ms = since.millisecondsSinceEpoch;
    return rows
        .where((r) => ((r[SyncColumns.updatedAt] as int?) ?? 0) > ms)
        .toList();
  }
}

class _Harness implements RemoteAdapterHarness {
  final _InMemoryRemote _remote = _InMemoryRemote();

  @override
  RemoteSyncAdapter get adapter => _remote;

  @override
  Future<void> seed(String table, List<Map<String, dynamic>> rows) async {
    final t = _remote.store.putIfAbsent(table, () => {});
    for (final r in rows) {
      t[r[SyncColumns.id] as String] = Map<String, dynamic>.from(r);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> backendRows(String table) async =>
      _remote.store[table]?.values
          .map((r) => Map<String, dynamic>.from(r))
          .toList() ??
      <Map<String, dynamic>>[];

  @override
  Future<void> dispose() async {}
}

void main() {
  runRemoteSyncAdapterContract(
    adapterName: 'InMemoryRemote',
    newHarness: _Harness.new,
  );
}
