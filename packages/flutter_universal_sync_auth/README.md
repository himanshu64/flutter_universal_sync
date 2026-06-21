# flutter_universal_sync_auth

**Offline-first authentication** for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. An offline-first app must stay usable when the network — and your auth
server — is unreachable. `AuthSession` caches the token locally so the identity
**survives offline**, refreshes transparently when back online, and hands Bearer
headers to your remote adapters.

Pure Dart, no plugins — inject your own `TokenStore` (secure storage) and
refresh function.

## Install

```yaml
dependencies:
  flutter_universal_sync_auth: ^0.1.0
```

## Usage

```dart
import 'package:flutter_universal_sync_auth/flutter_universal_sync_auth.dart';

final session = AuthSession(
  store: mySecureTokenStore,           // persists across launches
  refresher: (current) async {         // called when the token is expiring
    final res = await api.refresh(current.refreshToken!);
    return AuthToken(
      accessToken: res.access,
      refreshToken: res.refresh,
      expiresAt: res.expiresAt,
    );
  },
);

await session.load();                  // restore a cached token at startup

// after a successful login:
await session.signIn(AuthToken(
  accessToken: res.access,
  refreshToken: res.refresh,
  expiresAt: res.expiresAt,
));

// attach to every synced request:
final headers = await session.authHeaders(online: connectivity.isOnline);
// → {'authorization': 'Bearer <token>'}
```

## Behaviour

| Situation | What happens |
| --- | --- |
| Token valid | Returned as-is. |
| Token expiring, **online** | Refreshed via `refresher`, persisted, new token returned. Concurrent calls share **one** refresh. |
| Token expired, **offline** | The cached (stale) token is returned and `isAuthenticated` stays `true` — the app keeps serving local data and queuing writes. |
| Refresh **fails** | Falls back to the cached token; the user is **not** signed out. |
| Signed out | `accessToken()` is `null`, `authHeaders()` is empty. |

Pass `online:` from your connectivity source (see
[`ReachabilityMonitor`](../flutter_universal_sync_core/) in core) so the session
only attempts a refresh when there's a real connection.

### Persisting the token

`InMemoryTokenStore` is included for tests. In production implement `TokenStore`
over secure storage so the token survives restarts but stays protected:

```dart
class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<AuthToken?> read() async {
    final raw = await _storage.read(key: 'auth');
    return raw == null ? null : AuthToken.fromJson(jsonDecode(raw));
  }
  @override
  Future<void> write(AuthToken t) =>
      _storage.write(key: 'auth', value: jsonEncode(t.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: 'auth');
}
```

## License

MIT — see [LICENSE](LICENSE).
