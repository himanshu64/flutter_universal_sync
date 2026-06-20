/// Constraints the OS should satisfy before running a background sync job.
///
/// Maps onto WorkManager `Constraints` / BGTaskScheduler requirements. The
/// package is plugin-free, so the concrete scheduler (in your app) translates
/// these to the platform API.
class BackgroundConstraints {
  /// Creates constraints. Defaults: network required, no charging requirement.
  const BackgroundConstraints({
    this.requiresNetwork = true,
    this.requiresCharging = false,
  });

  /// Whether any network connection must be available.
  final bool requiresNetwork;

  /// Whether the device must be charging.
  final bool requiresCharging;
}

/// Schedules and cancels OS-level periodic background sync.
///
/// Implemented in your app over `workmanager` (Android WorkManager + iOS
/// BGTaskScheduler) — see the package README. Kept as an interface so this
/// package stays pure Dart and plugin-version-independent, mirroring how the
/// engine injects `ConnectivityMonitor`.
abstract class BackgroundScheduler {
  /// One-time setup (registers the platform callback). Idempotent.
  Future<void> initialize();

  /// Registers a periodic background sync at [frequency] (the OS enforces a
  /// floor, ~15 min) under [constraints].
  Future<void> schedulePeriodic({
    required Duration frequency,
    BackgroundConstraints constraints,
  });

  /// Cancels all scheduled background sync jobs.
  Future<void> cancelAll();
}
