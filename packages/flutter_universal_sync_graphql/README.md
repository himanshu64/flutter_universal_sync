# flutter_universal_sync_graphql

A GraphQL [`RemoteSyncAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. GraphQL schemas differ per backend, so you supply the query/mutation
builders.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_graphql: ^0.1.0
  http: ^1.2.2
```

## Use

```dart
final remote = GraphQLSyncAdapter(
  endpoint: Uri.parse('https://api.example.com/graphql'),
  pullQuery: (table, since) => '''
    { $table(where: { updated_at: { _gt: "${since?.toIso8601String() ?? ''}" } }) { id name updated_at } }
  ''',
  pushMutation: (e) => switch (e.operation) {
    SyncOperation.insert => 'mutation { insert_${e.table}_one(object: ${_json(e.payload)}) { id } }',
    SyncOperation.update => 'mutation { update_${e.table}(...) { affected_rows } }',
    SyncOperation.delete => 'mutation { delete_${e.table}(...) { affected_rows } }',
  },
  headers: () => {'authorization': 'Bearer $token'},
);
```

Omit `pushMutation` for a read-only endpoint — push then raises
`SyncPushException`. The pull result is read from `data[rootKey(table)]` (defaults
to the table name; override `rootKey` when they differ).

## Testing

Unit tests use `MockClient`. A live pull test runs against the read-only
[SpaceX GraphQL API](https://spacex-production.up.railway.app/):

```bash
dart test                 # unit
dart test -t integration  # live SpaceX
```

## License

MIT.
