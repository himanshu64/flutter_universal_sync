import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('offline syncNow is a no-op snapshot, queue untouched', () async {
    final local = InMemoryAdapter()..registerTable('users', _userColumns);
    final remote = FakeRemoteSyncAdapter();
    final connectivity = FakeConnectivityMonitor(initial: false);
    final clock = FakeClock();
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await local.transaction(() async {
      await local.enqueueSync(
        SyncQueueEntry(
          id: 'q1',
          table: 'users',
          entityId: 'u1',
          operation: SyncOperation.insert,
          payload: const {SyncColumns.id: 'u1'},
          createdAt: clock.now(),
        ),
      );
    });

    await engine.syncNow();
    expect(remote.pushed, isEmpty);
    expect(remote.pullCalls, isEmpty);
    final pending = await local.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(engine.current.status, EngineStatus.idle);
  });
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
