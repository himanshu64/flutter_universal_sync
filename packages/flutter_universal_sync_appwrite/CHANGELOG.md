# Changelog

## 0.1.0 — 2026-06-21

Initial release. Appwrite (Databases API) `RemoteSyncAdapter`.

### Added
- `AppwriteSyncAdapter`: insert→`POST .../documents` (`{documentId, data}`),
  update/delete→`PATCH .../documents/<id>`, pull→`GET .../documents` with
  `greaterThan("updated_at", ...)` queries, unwrapping `{documents: [...]}`.
  `x-appwrite-key` (server) or `x-appwrite-jwt` (client) auth. Non-2xx →
  `SyncPushException`/`SyncPullException`.
- `MockClient` unit tests (100% line coverage). Live verification needs an
  Appwrite project.
