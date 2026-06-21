# Changelog

## 0.1.0 — 2026-06-21

Initial release. Offline-first authentication for the
`flutter_universal_sync` family.

### Added
- `AuthSession` — caches an `AuthToken` in a `TokenStore` so the identity
  survives offline (`isAuthenticated` stays true even when expired/offline).
  When online it refreshes an expiring token transparently (single-flighted via
  an injected `TokenRefresher`), falls back to the cached token if refresh
  fails (never auto-signs-out), and exposes Bearer `authHeaders` for remote
  adapters.
- `AuthToken` — access/refresh tokens + expiry, with `isExpiredAt` and
  JSON round-trip.
- `TokenStore` interface + `InMemoryTokenStore`. Back it with
  `flutter_secure_storage` in production.
