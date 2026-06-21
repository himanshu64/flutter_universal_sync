# Changelog

## 0.2.0 — 2026-06-21

### Added
- `BatteryPolicy` + `BatterySnapshot` + `BatteryReader` — battery-gated runs.
  Pass a `batteryReader` to `BackgroundSyncCoordinator` and a depleted run is
  **skipped** before any database/network work (default: skip below 20% unless
  charging).
- `BackgroundSyncResult.skipped` — the run was deliberately not performed
  (battery too low, or a run was already in progress). Treat as success.
- Overlapping-wake **coalescing** — `runOnce` returns `skipped` if a run is
  already in progress, so concurrent OS wakes don't stack engine cycles.
- `BackgroundConstraints.requiresBatteryNotLow` (default `true`) and
  `requiresUnmeteredNetwork` — OS-level deferral to save battery / avoid
  cellular.

## 0.1.0 — 2026-06-21

Initial release. Headless background sync for the `flutter_universal_sync`
family.

### Added
- `BackgroundSyncCoordinator` — pure-Dart orchestrator that rebuilds the engine
  in a headless isolate (via a `SyncEngineFactory`), runs one
  `syncNow(pull: true)` cycle, always disposes the engine, and maps the outcome
  to `BackgroundSyncResult.success` / `.failure`. Never throws.
- `BackgroundScheduler` interface + `BackgroundConstraints` — implemented in
  your app over `workmanager` (Android WorkManager / iOS BGTaskScheduler); kept
  plugin-free so the package stays pure Dart and unit-testable.
- Verified with the engine built from `InMemoryAdapter` + the engine test
  doubles (100% line coverage).
