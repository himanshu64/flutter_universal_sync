# Changelog

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
