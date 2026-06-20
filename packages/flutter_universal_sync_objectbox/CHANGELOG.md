# Changelog

## 0.1.0 — 2026-06-21

Initial release (reference implementation). ObjectBox `LocalDatabaseAdapter`
for the `flutter_universal_sync` family.

### Added
- `SyncRecord` generic entity + `ObjectboxSyncAdapter` implementing the full
  core 0.2.0 `LocalDatabaseAdapter` contract via ObjectBox queries, mirroring
  the verified in-memory / Hive adapters (snapshot-based `transaction`
  rollback, in-memory schema tracking).

### Note
- Requires generated bindings (`dart run build_runner build`) and the ObjectBox
  native library. Not executed against the contract suite in the authoring
  environment (codegen + native-lib unavailable there) — see README.
