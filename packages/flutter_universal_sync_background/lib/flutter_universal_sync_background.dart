/// Headless background sync for the flutter_universal_sync family. Pure Dart;
/// supply a `workmanager`-backed `BackgroundScheduler` in your app (see the
/// README). The `BackgroundSyncCoordinator` runs one engine cycle per wake.
library;

export 'src/background_scheduler.dart';
export 'src/background_sync_coordinator.dart';
export 'src/battery_policy.dart';
