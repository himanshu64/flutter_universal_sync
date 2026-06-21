# flutter_universal_sync_appwrite

An [Appwrite](https://appwrite.io) (Databases API)
[`RemoteSyncAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. Each domain table maps to an Appwrite collection of the same id.

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_appwrite: ^0.1.0
  http: ^1.2.2
```

```dart
final remote = AppwriteSyncAdapter(
  endpoint: Uri.parse('https://cloud.appwrite.io/v1'),
  projectId: 'YOUR_PROJECT',
  databaseId: 'YOUR_DB',
  jwt: () => appwriteSession.jwt,   // client session, or apiKey: () => '...' for server
);
final engine = SyncEngine(remote: remote, /* ... */);
```

| Queue op | Request |
|---|---|
| insert | `POST .../collections/<table>/documents` (`{documentId, data}`) |
| update / delete | `PATCH .../documents/<id>` (`{data}`; delete sends the tombstone) |
| pull | `GET .../documents?queries[]=greaterThan("updated_at", <ms>)` → `{documents:[...]}` |

Your collections need `updated_at` / `deleted_at` attributes. Verified with
`MockClient`; point it at a real project to go live.

## License

MIT.
