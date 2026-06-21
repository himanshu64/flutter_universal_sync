import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

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
}

/// Pure-Dart orchestrator for a single headless background sync.
///
/// Build the engine, run one pull-sync cycle, and always dispose it (so the
/// background isolate leaves no open database handles). Platform-agnostic — the
/// WorkManager / BGTaskScheduler callback in your app calls [runOnce].
class BackgroundSyncCoordinator {
  /// Creates a coordinator that builds its engine with [engineFactory].
  BackgroundSyncCoordinator({required this.engineFactory});

  /// Rebuilds the engine for each run (fresh per background wake).
  final SyncEngineFactory engineFactory;

  /// Builds the engine, runs one `syncNow(pull: true)` cycle, disposes it, and
  /// reports the result. Never throws — failures map to
  /// [BackgroundSyncResult.failure].
  Future<BackgroundSyncResult> runOnce() async {
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
  }
}
