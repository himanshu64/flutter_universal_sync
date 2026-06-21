import 'dart:async';

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

  SyncEngine buildEngine() {
    final local = InMemoryAdapter()..registerTable('things', cols);
    final connectivity = FakeConnectivityMonitor(initial: true);
    monitors.add(connectivity);
    return SyncEngine(
      localDb: local,
      remote: FakeRemoteSyncAdapter(),
      connectivity: connectivity,
      tables: const {'things': TableConfig()},
    );
  }

  group('BatteryPolicy.allows', () {
    test('default policy gates on 20% unless charging', () {
      const p = BatteryPolicy();
      expect(p.allows(const BatterySnapshot(level: 0.1, charging: false)),
          isFalse);
      expect(
          p.allows(const BatterySnapshot(level: 0.1, charging: true)), isTrue);
      expect(
          p.allows(const BatterySnapshot(level: 0.5, charging: false)), isTrue);
    });

    test('allowWhenCharging:false ignores the charging state', () {
      const p = BatteryPolicy(minLevel: 0.3, allowWhenCharging: false);
      expect(
          p.allows(const BatterySnapshot(level: 0.1, charging: true)), isFalse);
      expect(
          p.allows(const BatterySnapshot(level: 0.5, charging: false)), isTrue);
    });
  });

  test('skips (no engine built) when battery is low and unplugged', () async {
    var built = 0;
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async {
        built++;
        return buildEngine();
      },
      batteryReader: () async =>
          const BatterySnapshot(level: 0.1, charging: false),
    );

    expect(await coordinator.runOnce(), BackgroundSyncResult.skipped);
    expect(built, 0); // killed before any DB/network work
  });

  test('runs while charging despite a low battery', () async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async => buildEngine(),
      batteryReader: () async =>
          const BatterySnapshot(level: 0.05, charging: true),
    );
    expect(await coordinator.runOnce(), BackgroundSyncResult.success);
  });

  test('runs when battery is above the threshold', () async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async => buildEngine(),
      batteryReader: () async =>
          const BatterySnapshot(level: 0.9, charging: false),
    );
    expect(await coordinator.runOnce(), BackgroundSyncResult.success);
  });

  test('overlapping wakes are coalesced — the second is skipped', () async {
    final gate = Completer<void>();
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async {
        await gate.future; // hold the first run open
        return buildEngine();
      },
    );

    final first = coordinator.runOnce();
    final second = await coordinator.runOnce(); // first still in flight
    expect(second, BackgroundSyncResult.skipped);

    gate.complete();
    expect(await first, BackgroundSyncResult.success);

    // After completion a fresh run proceeds normally.
    expect(await coordinator.runOnce(), BackgroundSyncResult.success);
  });

  test('constraints default to battery-not-low + network', () {
    const c = BackgroundConstraints();
    expect(c.requiresNetwork, isTrue);
    expect(c.requiresBatteryNotLow, isTrue);
    expect(c.requiresCharging, isFalse);
    expect(c.requiresUnmeteredNetwork, isFalse);
  });
}
