# Changelog

## 0.1.2 — 2026-06-21

### Added
- **Push-side conflict (409) resolution.** When a `pushChange` throws a
  `SyncPushException` with `isConflict` and a `serverState`, the push pipeline
  resolves it with the table's `ConflictResolver`, applies the merged row
  locally, rewrites the queued payload, and re-pushes **once** — instead of just
  backing off. A second failure (or a resolver error) falls through to normal
  backoff, bounding it to one attempt per drain.
- `SyncEngine.tableSyncedAt(table)` — when a table was last successfully pulled
  (recorded after every successful pull, even an empty one). Pair with core's
  `StalenessPolicy` to detect stale cached reads.

## 0.1.1 — 2026-06-21

### Added
- Optional `dependencies` callback on `SyncEngine` — FK-aware ordering. An entry
  is deferred to a later cycle while any entity it references still has unsynced
  work (e.g. a `task` insert waits for its `project` to be acknowledged). Acyclic
  relationships only; no core/adapter changes required.

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
