/// Offline-first authentication for the `flutter_universal_sync` family.
///
/// [AuthSession] caches an [AuthToken] in a [TokenStore] so the identity
/// survives offline, refreshes transparently when online, and provides Bearer
/// headers for remote adapters.
library;

export 'src/auth_session.dart';
export 'src/auth_token.dart';
export 'src/token_store.dart';
