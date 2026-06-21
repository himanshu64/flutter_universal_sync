import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import 'package:flutter_universal_sync_engine/testing.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late FakeConnectivityMonitor connectivity;
  late FakeClock clock;
  late SyncEngine engine;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    connectivity = FakeConnectivityMonitor(initial: true);
    clock = FakeClock();
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await connectivity.dispose();
  });

  test('initial snapshot is idle with pendingCount 0', () async {
    expect(engine.current.status, EngineStatus.idle);
    expect(engine.current.pendingCount, 0);
  });

  test('start is idempotent: second call does not double-listen', () async {
    await engine.start();
    final once = connectivity.listenerCount;
    await engine.start();
    expect(connectivity.listenerCount, once);
  });

  test('stop is idempotent and cancels listeners', () async {
    await engine.start();
    await engine.stop();
    expect(connectivity.listenerCount, 0);
    await engine.stop(); // no-op, no throw
  });

  test('start fires one immediate cycle when online', () async {
    await engine.enqueueTestEntry('u1');
    await engine.start();
    // Allow microtasks to drain.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, hasLength(1));
  });

  test('start does NOT fire a cycle when offline', () async {
    connectivity = FakeConnectivityMonitor(initial: false);
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    await engine.enqueueTestEntry('u1');
    await engine.start();
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, isEmpty);
  });

  test('online transition fires a cycle', () async {
    connectivity = FakeConnectivityMonitor(initial: false);
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    await engine.start();
    await engine.enqueueTestEntry('u1');
    connectivity.emit(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, hasLength(1));
  });

  test('stop awaits in-flight cycle', () async {
    remote.pushDelay = const Duration(milliseconds: 50);
    await engine.enqueueTestEntry('u1');
    await engine.start();
    final stopFuture = engine.stop();
    await stopFuture; // must not throw, must not return until cycle ends
    expect(remote.pushed, hasLength(1));
  });
}

extension on SyncEngine {
  /// Convenience for tests: enqueues a single insert against `users`.
  Future<void> enqueueTestEntry(String entityId) async {
    await localDb.transaction(() async {
      await localDb.upsert('users', {
        SyncColumns.id: entityId,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: 100,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      });
      await localDb.enqueueSync(
        SyncQueueEntry(
          id: 'q-$entityId',
          table: 'users',
          entityId: entityId,
          operation: SyncOperation.insert,
          payload: {SyncColumns.id: entityId},
          createdAt: clock.now(),
        ),
      );
    });
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
