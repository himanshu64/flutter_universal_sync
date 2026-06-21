import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_engine/testing.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';

void main() {
  const cols = [
    SyncColumns.id,
    SyncColumns.createdAt,
    SyncColumns.updatedAt,
    SyncColumns.deletedAt,
    SyncColumns.isSynced,
    SyncColumns.syncStatus,
  ];

  test('records tableSyncedAt after a successful pull (even when empty)',
      () async {
    final clock = FakeClock(start: DateTime.utc(2026, 6, 1, 9));
    final local = InMemoryAdapter()..registerTable('things', cols);
    final remote = FakeRemoteSyncAdapter()
      ..pullResponses['things'] = [<Map<String, dynamic>>[]];
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'things': TableConfig()},
      clock: clock,
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    expect(await engine.tableSyncedAt('things'), isNull); // never synced

    await engine.syncNow(pull: true);

    expect(await engine.tableSyncedAt('things'), clock.now());
    expect(
      const StalenessPolicy(Duration(minutes: 5))
          .isStale(await engine.tableSyncedAt('things'), clock.now()),
      isFalse,
    );
  });

  test('does not record a timestamp when the pull fails', () async {
    final clock = FakeClock();
    final local = InMemoryAdapter()..registerTable('things', cols);
    final remote = _BrokenRemote();
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'things': TableConfig()},
      clock: clock,
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await engine.syncNow(pull: true);
    expect(await engine.tableSyncedAt('things'), isNull);
  });
}

class _BrokenRemote implements RemoteSyncAdapter {
  @override
  Future<void> pushChange(SyncQueueEntry entry) async {}

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async =>
      throw SyncPullException(table: table, cause: 'boom');
}
