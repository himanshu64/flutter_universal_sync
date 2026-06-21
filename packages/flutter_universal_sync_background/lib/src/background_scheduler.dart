/// Constraints the OS should satisfy before running a background sync job.
///
/// Maps onto WorkManager `Constraints` / BGTaskScheduler requirements. The
/// package is plugin-free, so the concrete scheduler (in your app) translates
/// these to the platform API.
class BackgroundConstraints {
  /// Creates constraints. Defaults: network required; no charging requirement;
  /// the OS should not run the job while the battery is low.
  const BackgroundConstraints({
    this.requiresNetwork = true,
    this.requiresCharging = false,
    this.requiresBatteryNotLow = true,
    this.requiresUnmeteredNetwork = false,
  });

  /// Whether any network connection must be available.
  final bool requiresNetwork;

  /// Whether the device must be charging.
  final bool requiresCharging;

  /// Whether the OS should defer the job while the battery is low
  /// (WorkManager `setRequiresBatteryNotLow`). Saves battery by not waking on
  /// low charge.
  final bool requiresBatteryNotLow;

  /// Whether the job requires an unmetered (Wi-Fi/Ethernet) connection — defer
  /// heavy syncs off cellular.
  final bool requiresUnmeteredNetwork;
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
