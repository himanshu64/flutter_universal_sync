# Changelog

## 0.1.2 — 2026-06-21

### Added
- HTTP `409` now throws `SyncPushException(isConflict: true, serverState: …)` —
  the response body (if a JSON object) is surfaced as the server's current row,
  so the engine can resolve the conflict and re-push.

### Testing
- Runs core's shared `runRemoteSyncAdapterContract` against a `MockClient` fake
  REST server — a copy-paste template for verifying custom remote adapters.

## 0.1.1 — 2026-06-21

### Added
- `idempotencyKeys` (default `true`): push sends an `Idempotency-Key` header set
  to the stable queue-entry id, so a re-pushed entry deduplicates server-side.

## 0.1.0 — 2026-06-21

Initial release. REST `RemoteSyncAdapter` for the `flutter_universal_sync`
family.

### Added
- `RestSyncAdapter` mapping queue entries to RESTful requests
  (insert→POST, update→PUT, delete→DELETE) and pulling deltas via
  `GET /<table>?since=<ms>`. Accepts a JSON array or a `{"rows": [...]}`
  envelope. Pluggable auth `headers`, injectable `http.Client`.
- Non-2xx and transport failures raise `SyncPushException` /
  `SyncPullException`.
- Deterministic unit tests via `MockClient`, plus a live integration suite
  against `https://jsonplaceholder.typicode.com` (run `dart test -t integration`).
