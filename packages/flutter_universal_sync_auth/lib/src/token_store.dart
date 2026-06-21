import 'auth_token.dart';

/// Persists the cached [AuthToken] across launches so auth survives offline.
///
/// Back this with secure storage (`flutter_secure_storage` →
/// Keychain/Keystore) in production. [InMemoryTokenStore] is provided for tests
/// and ephemeral use.
abstract class TokenStore {
  /// Reads the stored token, or null if none.
  Future<AuthToken?> read();

  /// Persists [token], replacing any existing one.
  Future<void> write(AuthToken token);

  /// Removes the stored token.
  Future<void> clear();
}

/// A non-persistent [TokenStore] holding the token in memory.
class InMemoryTokenStore implements TokenStore {
  AuthToken? _token;

  @override
  Future<AuthToken?> read() async => _token;

  @override
  Future<void> write(AuthToken token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
