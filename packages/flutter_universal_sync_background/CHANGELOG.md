# Changelog

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
