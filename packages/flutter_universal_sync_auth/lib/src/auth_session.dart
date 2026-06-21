import 'auth_token.dart';
import 'token_store.dart';

/// Exchanges the [current] token for a fresh one (calls your backend's refresh
/// endpoint). Throws on failure (network down, refresh token rejected).
typedef TokenRefresher = Future<AuthToken> Function(AuthToken current);

/// An offline-first auth session.
///
/// The token is cached in a [TokenStore], so:
/// - the identity **survives offline** — [isAuthenticated] stays true even when
///   the access token has expired and the device is offline, letting the app
///   serve local data and queue writes;
/// - when online, an expiring token is **refreshed** transparently (single-
///   flighted, so concurrent callers trigger at most one refresh);
/// - if a refresh fails, the cached token is still returned rather than logging
///   the user out.
class AuthSession {
  /// Creates a session over [store], optionally refreshing via [refresher].
  /// [refreshLeeway] refreshes a token shortly before it actually expires.
  /// [now] is injectable for tests.
  AuthSession({
    required this.store,
    this.refresher,
    this.refreshLeeway = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Where the token is persisted.
  final TokenStore store;

  /// Optional refresher used when the token is expiring and the app is online.
  final TokenRefresher? refresher;

  /// How long before expiry a token is eligible for refresh.
  final Duration refreshLeeway;

  final DateTime Function() _now;
  AuthToken? _token;
  Future<AuthToken>? _refreshing;

  /// Loads any persisted token into memory (call once at startup).
  Future<void> load() async => _token = await store.read();

  /// The current cached token, or null when signed out.
  AuthToken? get token => _token;

  /// Whether a cached identity exists (true even if expired/offline).
  bool get isAuthenticated => _token != null;

  /// Stores [token] as the active session.
  Future<void> signIn(AuthToken token) async {
    _token = token;
    await store.write(token);
  }

  /// Clears the session and persisted token.
  Future<void> signOut() async {
    _token = null;
    _refreshing = null;
    await store.clear();
  }

  /// Returns a usable access token, refreshing first if it is expiring and
  /// [online] with a [refresher] and refresh token available. Offline or on
  /// refresh failure, returns the cached token. Null only when signed out.
  Future<String?> accessToken({bool online = true}) async {
    final current = _token;
    if (current == null) return null;

    if (online &&
        refresher != null &&
        current.refreshToken != null &&
        _shouldRefresh(current)) {
      try {
        final fresh = await (_refreshing ??= _doRefresh(current));
        return fresh.accessToken;
      } catch (_) {
        // Refresh failed — keep using the cached token (don't sign out).
      }
    }
    return _token?.accessToken;
  }

  /// Bearer auth headers for a remote adapter; empty when signed out.
  Future<Map<String, String>> authHeaders({bool online = true}) async {
    final token = await accessToken(online: online);
    return token == null ? const {} : {'authorization': 'Bearer $token'};
  }

  bool _shouldRefresh(AuthToken token) {
    final expiresAt = token.expiresAt;
    if (expiresAt == null) return false;
    return !_now().isBefore(expiresAt.subtract(refreshLeeway));
  }

  Future<AuthToken> _doRefresh(AuthToken current) async {
    try {
      final fresh = await refresher!(current);
      _token = fresh;
      await store.write(fresh);
      return fresh;
    } finally {
      _refreshing = null;
    }
  }
}
