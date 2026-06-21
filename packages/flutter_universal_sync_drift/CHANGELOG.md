# Changelog

## 0.1.0 — 2026-06-21

Initial release. drift `LocalDatabaseAdapter` for the
`flutter_universal_sync` family.

### Added
- `DriftSyncAdapter` implementing the full core 0.2.0
  `LocalDatabaseAdapter` contract over a drift `QueryExecutor`, driven by
  raw SQL (no code-gen). Inner writes participate in `transaction` and
  roll back on error via drift's transaction zone.
- Pure Dart: the `QueryExecutor` is injected, so the adapter runs under
  Flutter and under the Dart VM in tests (`NativeDatabase.memory()`).
- Verified against core's shared `runLocalDatabaseAdapterContract` suite.
