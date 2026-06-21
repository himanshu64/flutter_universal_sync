# Changelog

## 0.1.0 — 2026-06-21

Initial release. GraphQL `RemoteSyncAdapter` for the `flutter_universal_sync`
family.

### Added
- `GraphQLSyncAdapter` over a single `POST <endpoint>` with `{query}`. You
  supply per-table `pullQuery` builders and an optional `pushMutation` builder
  (omit it for a read-only endpoint). GraphQL `errors` and non-2xx map to
  `SyncPullException` / `SyncPushException`.
- `MockClient` unit tests, plus a live pull integration test against the SpaceX
  GraphQL API (`dart test -t integration`).
