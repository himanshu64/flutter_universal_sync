# Changelog

## 0.2.0 — 2026-04-30

Engine-support contract bumps. Required for `flutter_universal_sync_engine` 0.1.0.

### Added
- `SyncQueueEntry.nextRetryAt` field; round-trips through `toMap`/`fromMap`,
  participates in equality.
- `SyncColumns.nextRetryAt` constant + `SyncColumns.queueTypes` reference SQL.
- `SyncMetaColumns` (table `_sync_meta`, columns `key`, `value`).
- `LocalDatabaseAdapter.upsert(table, data)` — pull-pipeline write.
- `LocalDatabaseAdapter.getMeta(key)` / `setMeta(key, value)` / `deleteMeta(key)`.
- `LocalDatabaseAdapter.pendingForEntity(table, entityId)`.
- `LocalDatabaseAdapter.rewriteQueuePayload(entryId, payload)`.
- `LocalDatabaseAdapter.pendingSyncEntries(...)` gains a `readyAt` parameter
  (back-compat with the existing `{int? limit}` form).
- Contract-suite groups for every addition above; reusable by every adapter.
- `InMemoryAdapter` is now exported from
  `package:flutter_universal_sync_core/testing.dart` so downstream packages
  (e.g. the sync engine) can reuse it as a local-store test double.

### Changed
- `LocalDatabaseAdapter.recordSyncFailure(...)` now increments `retry_count`
  and accepts `nextRetryAt`. Pass `incrementRetryCount: false` and omit
  `nextRetryAt` to retain 0.1.0 "just store the error" behaviour.

### Migration (for 0.1.0 adapters; none published yet)
- Add `next_retry_at INTEGER` to your sync queue table.
- Create `_sync_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)`.
- Implement the seven new / amended methods above.
- The shared contract suite exercises every new method — run it.

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
