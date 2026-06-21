import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import 'battery_policy.dart';

/// Rebuilds a fully-wired [SyncEngine] inside the (headless) background
/// isolate. It must construct the local adapter, remote adapter, connectivity
/// monitor, and table config from scratch — the OS isolate shares no live
/// objects with the UI isolate.
typedef SyncEngineFactory = Future<SyncEngine> Function();

/// The outcome of one background run, mapped by the platform binding to the
/// OS scheduler's success/retry result.
enum BackgroundSyncResult {
  /// The cycle completed without a push or pull error.
  success,

  /// The cycle errored or threw; the OS should retry later.
  failure,

  /// The cycle was deliberately not run (battery too low, or a run was already
  /// in progress). The OS should treat this as success — wait for the next
  /// scheduled wake rather than retry soon.
  skipped,
}

/// Pure-Dart orchestrator for a single headless background sync.
///
/// Build the engine, run one pull-sync cycle, and always dispose it (so the
/// background isolate leaves no open database handles). Platform-agnostic — the
/// WorkManager / BGTaskScheduler callback in your app calls [runOnce].
class BackgroundSyncCoordinator {
  /// Creates a coordinator that builds its engine with [engineFactory].
  ///
  /// Pass a [batteryReader] (e.g. backed by `battery_plus`) to gate runs on the
  /// battery state per [batteryPolicy] — a depleted run is skipped before any
  /// database or network work.
  BackgroundSyncCoordinator({
    required this.engineFactory,
    this.batteryReader,
    this.batteryPolicy = const BatteryPolicy(),
  });

  /// Rebuilds the engine for each run (fresh per background wake).
  final SyncEngineFactory engineFactory;

  /// Optional battery reader; when null, runs are not battery-gated.
  final BatteryReader? batteryReader;

  /// Policy applied to [batteryReader]'s result.
  final BatteryPolicy batteryPolicy;

  bool _running = false;

  /// Builds the engine, runs one `syncNow(pull: true)` cycle, disposes it, and
  /// reports the result. Never throws — failures map to
  /// [BackgroundSyncResult.failure].
  ///
  /// Returns [BackgroundSyncResult.skipped] without doing any work if a run is
  /// already in progress (overlapping wakes are coalesced) or the battery
  /// policy rejects the current charge.
  Future<BackgroundSyncResult> runOnce() async {
    if (_running) return BackgroundSyncResult.skipped;
    _running = true;
    try {
      final reader = batteryReader;
      if (reader != null && !batteryPolicy.allows(await reader())) {
        return BackgroundSyncResult.skipped;
      }

      SyncEngine? engine;
      try {
        engine = await engineFactory();
        await engine.syncNow(pull: true);
        return engine.current.status == EngineStatus.error
            ? BackgroundSyncResult.failure
            : BackgroundSyncResult.success;
      } catch (_) {
        return BackgroundSyncResult.failure;
      } finally {
        await engine?.dispose();
      }
    } finally {
      _running = false;
    }
  }
}
