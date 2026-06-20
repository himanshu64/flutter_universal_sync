# flutter_universal_sync_firebase

A [Cloud Firestore](https://firebase.google.com/docs/firestore)
[`RemoteSyncAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family, over the **Firestore REST API** — pure Dart, no Firebase SDK required.

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_firebase: ^0.1.0
  http: ^1.2.2
```

```dart
final remote = FirebaseSyncAdapter(
  projectId: 'YOUR_PROJECT',
  idToken: () => firebaseAuth.currentUser!.getIdTokenSync(),  // rotating token
);
final engine = SyncEngine(remote: remote, /* ... */);
```

| Queue op | Request |
|---|---|
| insert / update / delete | `PATCH <docs>/<table>/<id>` with `{fields}` (upsert; delete = tombstone) |
| pull | `POST <docs>:runQuery` filtering `updated_at > since` |

Rows are translated to/from Firestore's typed values by `FirestoreValueCodec`
(null/bool/int/double/String/List/Map). Verified with `MockClient` + codec
round-trip tests; point it at a real project (and a valid ID token) to go live.

> Need `timestampValue`/`bytesValue`/`referenceValue`/`geoPointValue`? Extend
> `FirestoreValueCodec` — they're intentionally out of scope for v1.

## License

MIT.
