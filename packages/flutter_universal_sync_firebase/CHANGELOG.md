# Changelog

## 0.1.0 — 2026-06-21

Initial release. Cloud Firestore `RemoteSyncAdapter` (Firestore REST).

### Added
- `FirebaseSyncAdapter`: insert/update/delete → `PATCH <docs>/<table>/<id>`
  (upsert; delete carries the tombstone), pull → `POST <docs>:runQuery` with a
  `structuredQuery` filtering `updated_at > since`. Bearer ID-token auth.
- `FirestoreValueCodec` — converts plain Dart rows to/from Firestore typed
  values (null/bool/int/double/String/List/Map). `timestampValue`/`bytesValue`/
  `referenceValue`/`geoPointValue` are out of scope for v1.
- `MockClient` unit tests + codec round-trip tests (98.8% coverage). Live
  verification needs a Firebase project + ID token.
