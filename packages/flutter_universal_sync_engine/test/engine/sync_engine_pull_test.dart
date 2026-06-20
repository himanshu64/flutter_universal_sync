import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('syncNow(pull: true) iterates every registered table', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', _userColumns)
      ..registerTable('orders', _userColumns);
    final remote = FakeRemoteSyncAdapter()
      ..pullResponses['users'] = [<Map<String, dynamic>>[]]
      ..pullResponses['orders'] = [<Map<String, dynamic>>[]];
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {
        'users': TableConfig(),
        'orders': TableConfig(),
      },
      clock: FakeClock(),
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await engine.syncNow(pull: true);

    expect(remote.pullCalls.map((c) => c.table), ['users', 'orders']);
  });

  test('error in pulling one table does not stop other tables', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', _userColumns)
      ..registerTable('orders', _userColumns);
    final remote = _BrokenUsersRemote()
      ..pullResponses['orders'] = [<Map<String, dynamic>>[]];
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {
        'users': TableConfig(),
        'orders': TableConfig(),
      },
      clock: FakeClock(),
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await engine.syncNow(pull: true);

    expect(remote.pullCalls.map((c) => c.table).toSet(), {'users', 'orders'});
    expect(engine.current.status, EngineStatus.error);
    expect(engine.current.lastError, contains('users-down'));
  });
}

class _BrokenUsersRemote extends FakeRemoteSyncAdapter {
  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    pullCalls.add((table: table, since: since));
    if (table == 'users') {
      throw Exception('users-down');
    }
    final canned = pullResponses[table];
    if (canned == null || canned.isEmpty) return const [];
    return canned.removeAt(0);
  }
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
