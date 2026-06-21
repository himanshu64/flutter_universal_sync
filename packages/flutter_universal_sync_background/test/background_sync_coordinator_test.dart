import 'package:flutter_universal_sync_background/flutter_universal_sync_background.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_engine/testing.dart';
import 'package:test/test.dart';

void main() {
  const cols = [
    SyncColumns.id,
    SyncColumns.createdAt,
    SyncColumns.updatedAt,
    SyncColumns.deletedAt,
    SyncColumns.isSynced,
    SyncColumns.syncStatus,
  ];

  final monitors = <FakeConnectivityMonitor>[];
  tearDown(() async {
    for (final m in monitors) {
      await m.dispose();
    }
    monitors.clear();
  });

  /// Builds an engine factory, optionally seeding one pending entry and
  /// canned push outcomes. [captured] receives the built engine.
  SyncEngineFactory factoryFor({
    bool online = true,
    bool seedPending = false,
    List<Object?> pushOutcomes = const [],
    List<SyncEngine>? captured,
  }) {
    return () async {
      final local = InMemoryAdapter()..registerTable('things', cols);
      if (seedPending) {
        await local.enqueueSync(SyncQueueEntry(
          id: 'q1',
          table: 'things',
          entityId: 't1',
          operation: SyncOperation.insert,
          payload: const {'id': 't1'},
          createdAt: DateTime.utc(2026, 1, 1),
        ));
      }
      final remote = FakeRemoteSyncAdapter()..pushOutcomes.addAll(pushOutcomes);
      final connectivity = FakeConnectivityMonitor(initial: online);
      monitors.add(connectivity);
      final engine = SyncEngine(
        localDb: local,
        remote: remote,
        connectivity: connectivity,
        tables: const {'things': TableConfig()},
      );
      captured?.add(engine);
      return engine;
    };
  }

  test('clean cycle → success', () async {
    final coordinator =
        BackgroundSyncCoordinator(engineFactory: factoryFor(seedPending: true));
    expect(await coordinator.runOnce(), BackgroundSyncResult.success);
  });

  test('offline cycle is a no-op → success (queue untouched)', () async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: factoryFor(online: false, seedPending: true),
    );
    expect(await coordinator.runOnce(), BackgroundSyncResult.success);
  });

  test('push error → failure', () async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: factoryFor(
        seedPending: true,
        pushOutcomes: [Exception('boom')],
      ),
    );
    expect(await coordinator.runOnce(), BackgroundSyncResult.failure);
  });

  test('factory throwing → failure (no crash)', () async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async => throw StateError('cannot open db'),
    );
    expect(await coordinator.runOnce(), BackgroundSyncResult.failure);
  });

  test('engine is always disposed after a run', () async {
    final captured = <SyncEngine>[];
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: factoryFor(captured: captured),
    );
    await coordinator.runOnce();
    expect(captured, hasLength(1));
    // syncNow after dispose throws — proves the engine was disposed.
    expect(() => captured.single.syncNow(), throwsStateError);
  });
}
