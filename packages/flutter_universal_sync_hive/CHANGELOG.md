# Changelog

## 0.1.2 — 2026-06-21

### Added
- Implements `PaginatedAdapter` (`getPage`) — keyset pagination over the box,
  reusing core's `paginateRows`. Stable under inserts/deletes.

## 0.1.1 — 2026-06-21

### Added
- Optional 32-byte `encryptionKey` — stores every box (domain rows, queue, meta)
  AES-256 encrypted at rest via Hive's `HiveAesCipher`.
- Implements `PurgeableAdapter` (`purgeSynced`) for cache eviction — hard-removes
  synced domain rows by age and/or keep-latest count, never touching pending rows.


## 0.1.0 — 2026-06-21

Initial release. Hive `LocalDatabaseAdapter` for the
`flutter_universal_sync` family.

### Added
- `HiveSyncAdapter` implementing the full core 0.2.0
  `LocalDatabaseAdapter` contract over Hive boxes (JSON-encoded values).
- Snapshot-based `transaction` rollback (Hive has no native transactions).
- Stable queue ordering via a monotonic sequence (Hive box iteration order
  is not insertion-stable), reloaded on `init` for restart-safety.
- In-memory schema tracking via `registerTable` for `validateSchema`.
- Verified against core's shared `runLocalDatabaseAdapterContract` suite.
