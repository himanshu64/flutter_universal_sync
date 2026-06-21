# flutter_universal_sync_background

Headless, OS-scheduled background sync for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. Runs the engine from a background isolate when the app is backgrounded or
killed.

Pure Dart: the orchestration is testable and plugin-free; you supply the
platform scheduler (WorkManager / BGTaskScheduler) — exactly how the engine
injects `ConnectivityMonitor`.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_engine: ^0.1.0
  flutter_universal_sync_background: ^0.1.0
  workmanager: ^0.5.0   # in your app, for the scheduler binding below
```

## How it works

The OS wakes a **fresh isolate** with no live objects from your UI. The
background callback rebuilds the engine and runs one cycle:

```dart
// A top-level entry point — required by workmanager's headless isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    final coordinator = BackgroundSyncCoordinator(
      engineFactory: () async {
        // Rebuild EVERYTHING fresh here (no closures from the UI isolate):
        final local = SqfliteSyncAdapter(/* ... */)..init();
        final remote = RestSyncAdapter(/* ... */);
        return SyncEngine(
          localDb: local,
          remote: remote,
          connectivity: ConnectivityPlusMonitor(),
          tables: const {'things': TableConfig()},
        );
      },
    );
    final result = await coordinator.runOnce();
    return result == BackgroundSyncResult.success;   // tells the OS to retry on false
  });
}
```

Wire the scheduler once, from your UI isolate:

```dart
Future<void> main() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'sync', 'sync',
    frequency: const Duration(minutes: 15),       // OS floor
    constraints: Constraints(networkType: NetworkType.connected),
  );
  runApp(const MyApp());
}
```

You can wrap that registration behind the package's `BackgroundScheduler`
interface so app code stays declarative:

```dart
class WorkmanagerScheduler implements BackgroundScheduler {
  @override
  Future<void> initialize() => Workmanager().initialize(callbackDispatcher);
  @override
  Future<void> schedulePeriodic({required Duration frequency, BackgroundConstraints constraints = const BackgroundConstraints()}) =>
      Workmanager().registerPeriodicTask('sync', 'sync',
          frequency: frequency,
          constraints: Constraints(
            networkType: constraints.requiresNetwork ? NetworkType.connected : NetworkType.notRequired,
            requiresCharging: constraints.requiresCharging,
          ));
  @override
  Future<void> cancelAll() => Workmanager().cancelAll();
}
```

## Design

The OS wakes a **fresh isolate** with no live objects from the UI isolate, so the
background callback must rebuild everything and tear it down:

```
OS background wake ─▶ callbackDispatcher (your app, @pragma vm:entry-point)
                         │  builds adapters in the headless isolate
                         ▼
                 BackgroundSyncCoordinator.runOnce()   ← this package (pure Dart)
                         │  build engine → syncNow(pull) → dispose
                         ▼
                 BackgroundSyncResult.success / .failure  → OS retry policy
```

Three types:

- **`SyncEngineFactory`** — `Future<SyncEngine> Function()`; rebuilds a fully
  wired engine inside the background isolate (no closures captured from the UI).
- **`BackgroundSyncCoordinator`** — builds the engine, runs one
  `syncNow(pull: true)`, **always disposes** it (no leaked DB handles), and maps
  the result to `success`/`failure`. Never throws.
- **`BackgroundScheduler`** + `BackgroundConstraints` — the OS-scheduler
  interface you implement over `workmanager` (above).

**Why no direct `workmanager` dependency** — the same three reasons the engine
doesn't import `connectivity_plus`: it would make the package Flutter-only, lock
us to that plugin's (churny) versioning, and prevent pure-Dart unit tests. The
orchestration is fully unit-tested with the engine's in-memory test doubles.

## Known limitations

- The OS enforces a ~15-minute minimum period; this is for catch-up sync, not
  real-time — that's the foreground engine's job.
- iOS background execution is best-effort and OS-budgeted.
- One periodic job pulls all registered tables; no per-table scheduling in v1.

## License

MIT.
