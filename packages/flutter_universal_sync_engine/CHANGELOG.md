# Changelog

## 0.1.0 — 2026-04-30

Initial release. Sync engine for the `flutter_universal_sync` family.

### Added
- `SyncEngine` with hybrid lifecycle (`start`/`stop` + `syncNow`).
- `Stream<SyncStateSnapshot>` with BehaviorSubject semantics; coarse
  `EngineStatus` (idle / syncing / error).
- `ConnectivityMonitor` abstract interface (consumers supply impl).
- `TableConfig` with per-table `ConflictResolver` (extensible).
- `defaultBackoff` exponential schedule, capped at 5 minutes.
- Push pipeline: per-entity grouping, fail-stop within group,
  cross-group continuation, `next_retry_at`-aware skipping.
- Pull pipeline: per-table delta fetch via `since` cursor, conflict
  resolver invoked only when local has a pending edit, idempotent
  cursor advancement.
- Test doubles: `FakeConnectivityMonitor`, `FakeRemoteSyncAdapter`
  (exported via `package:flutter_universal_sync_engine/testing.dart`).
