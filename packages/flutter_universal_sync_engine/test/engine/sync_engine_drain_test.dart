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

  Future<void> seed(String id) async {
    await local.transaction(() async {
      await local.upsert('users', {
        SyncColumns.id: id,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: 100,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      });
      await local.enqueueSync(
        SyncQueueEntry(
          id: 'q-$id',
          table: 'users',
          entityId: id,
          operation: SyncOperation.insert,
          payload: {SyncColumns.id: id},
          createdAt: clock.now(),
        ),
      );
    });
  }

  test('syncNow emits idle → syncing → idle', () async {
    await seed('u1');
    final snapshots = <EngineStatus>[];
    final sub = engine.state.listen((s) => snapshots.add(s.status));
    await engine.syncNow();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(
      snapshots,
      [EngineStatus.idle, EngineStatus.syncing, EngineStatus.idle],
    );
  });

  test('two syncNow calls coalesce into one cycle', () async {
    remote.pushDelay = const Duration(milliseconds: 30);
    await seed('u1');
    final f1 = engine.syncNow();
    final f2 = engine.syncNow();
    await Future.wait([f1, f2]);
    expect(remote.pushed, hasLength(1));
  });

  test('late subscriber receives the current snapshot immediately', () async {
    final received = <EngineStatus>[];
    final sub = engine.state.listen((s) => received.add(s.status));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(received, [EngineStatus.idle]);
  });

  test('snapshot pendingCount reflects queue size', () async {
    await seed('u1');
    await seed('u2');
    expect(engine.current.pendingCount, 0);
    final cycle = engine.syncNow();
    // Capture the syncing snapshot mid-cycle
    SyncStateSnapshot? snap;
    final sub = engine.state.listen((s) {
      if (s.status == EngineStatus.syncing) snap = s;
    });
    await cycle;
    await sub.cancel();
    expect(snap, isNotNull);
    expect(snap!.pendingCount, 2);
  });

  test('error in push surfaces as EngineStatus.error with lastError', () async {
    await seed('u1');
    remote.pushOutcomes.add(Exception('boom'));
    await engine.syncNow();
    expect(engine.current.status, EngineStatus.error);
    expect(engine.current.lastError, contains('boom'));
  });

  test('successful syncNow updates lastSyncedAt', () async {
    await seed('u1');
    final before = engine.current.lastSyncedAt;
    await engine.syncNow();
    expect(engine.current.lastSyncedAt, isNot(before));
    expect(engine.current.lastSyncedAt, clock.now());
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
