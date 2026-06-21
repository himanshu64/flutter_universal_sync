# Changelog

## 0.1.0 — 2026-06-21

Initial release. sqflite `LocalDatabaseAdapter` for the
`flutter_universal_sync` family.

### Added
- `SqfliteSyncAdapter` implementing the full core 0.2.0
  `LocalDatabaseAdapter` contract (domain CRUD, `upsert`, the sync queue
  with `next_retry_at` backoff, `_sync_meta` KV, `pendingForEntity`,
  `rewriteQueuePayload`, atomic `transaction`, `validateSchema`).
- Pure Dart: the `DatabaseFactory` is injected, so the adapter runs under
  Flutter (`package:sqflite`) and under the Dart VM in tests
  (`package:sqflite_common_ffi`).
- Verified against core's shared `runLocalDatabaseAdapterContract` suite.
