# Changelog

## 0.2.0 — Unreleased

Engine-support contract bumps. See spec
`docs/superpowers/specs/2026-04-30-sync-engine-design.md` §4.

### Added
- (filled in across Tasks 1–8 of the engine plan)

### Changed
- (filled in across Tasks 1–8 of the engine plan)

### Migration
- 0.1.0 adapters need to add the `next_retry_at INTEGER` column to the
  sync queue table and create the `_sync_meta(key TEXT PRIMARY KEY,
  value TEXT NOT NULL)` table. No 0.1.0 adapters are published yet.

## 0.1.0 — 2026-04-24

Initial release. Contracts layer for the `flutter_universal_sync` family.

### Added
- `SyncEntity` abstract base class with the six sync-metadata fields.
- `SyncQueueEntry` data class with `copyWith`, `toMap`/`fromMap`, and structural equality.
- `SyncOperation` (`insert` / `update` / `delete`) and `SyncStatus` (`pending` / `syncing` / `synced` / `failed`) enums.
- `LocalDatabaseAdapter` interface covering domain CRUD, sync queue, atomic transactions, and schema validation.
- `RemoteSyncAdapter` interface for per-op push and delta pull.
- `ConflictResolver` interface plus three built-in strategies: `LastWriteWinsResolver`, `ServerPriorityResolver`, `ClientPriorityResolver`.
- `SyncColumns` schema constants.
- `SyncException` sealed hierarchy (`SchemaValidationException`, `SyncPushException`, `SyncPullException`, `ConflictResolutionException`).
- `IdGenerator` / `UuidV4Generator`.
- Shared `runLocalDatabaseAdapterContract` test suite for downstream adapter packages (exported via `package:flutter_universal_sync_core/testing.dart`).

### Known limitations
See README "Known v1 limitations" for the list of accepted `0.1.0` trade-offs.
