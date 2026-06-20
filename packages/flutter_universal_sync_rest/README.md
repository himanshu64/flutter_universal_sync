# flutter_universal_sync_rest

A REST [`RemoteSyncAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family — pushes queue entries and pulls deltas over plain HTTP/JSON.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_rest: ^0.1.0
  http: ^1.2.2
```

## Convention

| Queue op | Request |
|---|---|
| insert | `POST   <baseUrl>/<table>` (body = payload) |
| update | `PUT    <baseUrl>/<table>/<entityId>` (body = payload) |
| delete | `DELETE <baseUrl>/<table>/<entityId>` |
| pull   | `GET    <baseUrl>/<table>?since=<millis>` → JSON array, or `{"rows": [...]}` |

Non-2xx responses raise `SyncPushException` / `SyncPullException`, which the
engine records and retries with backoff.

## Use

```dart
final remote = RestSyncAdapter(
  baseUrl: Uri.parse('https://api.example.com/v1'),
  headers: () => {'authorization': 'Bearer $token'},
);

final engine = SyncEngine(remote: remote, /* ... */);
```

## Testing

Deterministic unit tests use `package:http/testing`'s `MockClient`. A live
integration suite runs against [jsonplaceholder](https://jsonplaceholder.typicode.com):

```bash
dart test                 # unit tests
dart test -t integration  # live jsonplaceholder checks
```

> jsonplaceholder accepts writes but doesn't persist them, so the integration
> tests verify request/response handling, not server-side round-trips.

## License

MIT.
