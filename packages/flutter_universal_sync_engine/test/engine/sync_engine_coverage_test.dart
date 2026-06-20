import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';
import 'package:flutter_universal_sync_engine/testing.dart';
import 'package:test/test.dart';

/// Pins the production code paths the fast unit tests bypass: the public
/// (system-clock) constructor, the real [Clock], the dispose guards, and
/// the periodic-timer trigger.
void main() {
  test('public constructor builds an idle engine on the system clock',
      () async {
    final engine = SyncEngine(
      localDb: InMemoryAdapter()..registerTable('users', _userColumns),
      remote: FakeRemoteSyncAdapter(),
      connectivity: FakeConnectivityMonitor(initial: false),
      tables: const {'users': TableConfig()},
    );
    expect(engine.current.status, EngineStatus.idle);
    expect(engine.current.pendingCount, 0);
    await engine.dispose();
  });

  test('Clock.systemClock reports UTC now and delays', () async {
    final now = Clock.systemClock.now();
    expect(now.isUtc, isTrue);
    await Clock.systemClock.delay(Duration.zero);
  });

  test('start() and syncNow() throw after dispose', () async {
    final engine = SyncEngine(
      localDb: InMemoryAdapter()..registerTable('users', _userColumns),
      remote: FakeRemoteSyncAdapter(),
      connectivity: FakeConnectivityMonitor(initial: false),
      tables: const {'users': TableConfig()},
    );
    await engine.dispose();
    await expectLater(engine.start(), throwsStateError);
    expect(() => engine.syncNow(), throwsStateError);
  });

  test('periodic timer trigger fires a cycle', () async {
    final local = InMemoryAdapter()..registerTable('users', _userColumns);
    final remote = FakeRemoteSyncAdapter();
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      drainInterval: const Duration(milliseconds: 20),
    );
    await local.enqueueSync(
      SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.insert,
        payload: const {'id': 'u1'},
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await engine.start();
    // Let several periodic ticks fire on the real clock.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await engine.stop();
    await engine.dispose();
    await connectivity.dispose();

    expect(remote.pushed, isNotEmpty);
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
