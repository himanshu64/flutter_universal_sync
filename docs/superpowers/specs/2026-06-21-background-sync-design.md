# `flutter_universal_sync_background` — Design Spec (Plan 3)

> **Status:** design + implementation. Wraps the engine for headless,
> OS-scheduled background sync.
> **Predecessor:** the sync engine — `packages/flutter_universal_sync_engine/` (see its README).

## 1. Goal

Run a sync cycle when the app is backgrounded or killed — on Android via
WorkManager, on iOS via BGTaskScheduler. The OS wakes a **fresh headless
isolate**, so there are no live objects from the UI isolate: the background
callback must rebuild the engine from scratch, run one cycle, and tear down.

## 2. Architecture — pure-Dart core, platform glue downstream

The package keeps the same discipline as the engine (which injects
`ConnectivityMonitor` rather than importing `connectivity_plus`): the
**orchestration is pure Dart and unit-tested**; the OS-scheduler binding lives
in the app via a small interface.

```
OS background wake ─▶ callbackDispatcher (app, @pragma vm:entry-point)
                         │  builds adapters in the headless isolate
                         ▼
                 BackgroundSyncCoordinator.runOnce()   ← this package (pure Dart)
                         │  build engine → syncNow(pull) → dispose
                         ▼
                 BackgroundSyncResult.success / .failure  → OS retry policy
```

### 2.1 `SyncEngineFactory`

```dart
typedef SyncEngineFactory = Future<SyncEngine> Function();
```

The factory rebuilds a fully-wired engine (local adapter, remote adapter,
connectivity, tables) **inside the background isolate**. It cannot capture
closures from the UI isolate, so it constructs everything fresh.

### 2.2 `BackgroundSyncCoordinator`

```dart
class BackgroundSyncCoordinator {
  BackgroundSyncCoordinator({required SyncEngineFactory engineFactory});
  Future<BackgroundSyncResult> runOnce();   // build → syncNow(pull:true) → dispose
}

enum BackgroundSyncResult { success, failure }
```

`runOnce` always disposes the engine (even on throw) so the headless isolate
leaves no open DB handles. It maps a clean cycle to `success` and an
errored/throwing cycle to `failure`, which the platform binding translates to
the OS's "succeeded / retry" result.

### 2.3 `BackgroundScheduler` (interface)

```dart
abstract class BackgroundScheduler {
  Future<void> initialize();
  Future<void> schedulePeriodic({required Duration frequency, BackgroundConstraints constraints});
  Future<void> cancelAll();
}
```

The app implements this with `workmanager` (Android/iOS). The package ships the
interface + a `BackgroundConstraints` value type (network-required, charging,
etc.) so app code is declarative and the package stays plugin-free.

## 3. Why not depend on `workmanager` directly

Same three reasons the engine doesn't depend on `connectivity_plus`: it would
make the package Flutter-only, lock us to that plugin's (churny) versioning, and
prevent pure-Dart unit tests. The README ships a copy-pasteable WorkManager
`callbackDispatcher` so wiring isn't a hidden tax.

## 4. Testing

- `BackgroundSyncCoordinator` is unit-tested against a real `SyncEngine` built
  from `InMemoryAdapter` + the engine's `FakeRemoteSyncAdapter` /
  `FakeConnectivityMonitor` — success path, push-error → failure, factory-throw
  → failure, and engine-always-disposed.
- The WorkManager binding is a thin documented adapter (cannot be headless
  unit-tested; it runs only inside the OS scheduler).

## 5. Known v1 limitations

- Minimum OS period is ~15 min (WorkManager/BGTaskScheduler floor); not for
  real-time sync — that's the foreground engine's job.
- iOS background execution is best-effort and budget-limited by the OS.
- One periodic job that pulls all registered tables; no per-table scheduling.
