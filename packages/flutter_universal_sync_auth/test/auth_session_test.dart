import 'dart:async';

import 'package:flutter_universal_sync_auth/flutter_universal_sync_auth.dart';
import 'package:test/test.dart';

void main() {
  final base = DateTime.utc(2026, 1, 1, 12);

  AuthToken token({
    String access = 'a1',
    String? refresh = 'r1',
    Duration? ttl = const Duration(hours: 1),
  }) =>
      AuthToken(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: ttl == null ? null : base.add(ttl),
      );

  test('AuthToken round-trips through JSON', () {
    final t = token();
    final back = AuthToken.fromJson(t.toJson());
    expect(back.accessToken, 'a1');
    expect(back.refreshToken, 'r1');
    expect(back.expiresAt, t.expiresAt);

    final noExpiry = AuthToken.fromJson(
      const AuthToken(accessToken: 'x').toJson(),
    );
    expect(noExpiry.expiresAt, isNull);
  });

  test('AuthToken.isExpiredAt reflects the expiry', () {
    final t = token(); // expires at base + 1h
    expect(t.isExpiredAt(base), isFalse);
    expect(t.isExpiredAt(base.add(const Duration(hours: 2))), isTrue);
    expect(token(ttl: null).isExpiredAt(base), isFalse); // never expires
  });

  test('signIn caches + persists; load restores; signOut clears', () async {
    final store = InMemoryTokenStore();
    final session = AuthSession(store: store, now: () => base);

    expect(session.isAuthenticated, isFalse);
    await session.signIn(token());
    expect(session.isAuthenticated, isTrue);
    expect(await store.read(), isNotNull);

    final reloaded = AuthSession(store: store, now: () => base);
    await reloaded.load();
    expect(reloaded.token?.accessToken, 'a1');

    await session.signOut();
    expect(session.isAuthenticated, isFalse);
    expect(await store.read(), isNull);
  });

  test('returns the current token while it is still valid', () async {
    var refreshed = 0;
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => base,
      refresher: (_) async {
        refreshed++;
        return token(access: 'new');
      },
    );
    await session.signIn(token()); // expires in 1h, now=base

    expect(await session.accessToken(), 'a1');
    expect(refreshed, 0); // not expiring → no refresh
  });

  test('refreshes transparently when the token is expiring and online',
      () async {
    var now = base;
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => now,
      refresher: (current) async {
        expect(current.refreshToken, 'r1');
        return token(
            access: 'a2', refresh: 'r2', ttl: const Duration(hours: 2));
      },
    );
    await session.signIn(token()); // expires at base+1h
    now = base.add(const Duration(minutes: 61)); // past expiry

    expect(await session.accessToken(), 'a2');
    expect(session.token?.refreshToken, 'r2'); // new token persisted
    expect((await session.store.read())?.accessToken, 'a2');
  });

  test('offline never refreshes — serves the cached (stale) token', () async {
    var now = base;
    var refreshed = 0;
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => now,
      refresher: (_) async {
        refreshed++;
        return token(access: 'a2');
      },
    );
    await session.signIn(token());
    now = base.add(const Duration(hours: 2)); // expired

    expect(await session.accessToken(online: false), 'a1'); // stale but usable
    expect(session.isAuthenticated, isTrue); // identity survives offline
    expect(refreshed, 0);
  });

  test('falls back to the cached token when refresh fails', () async {
    var now = base;
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => now,
      refresher: (_) async => throw Exception('refresh endpoint down'),
    );
    await session.signIn(token());
    now = base.add(const Duration(hours: 2));

    expect(await session.accessToken(), 'a1'); // not signed out
    expect(session.isAuthenticated, isTrue);
  });

  test('concurrent calls trigger a single refresh', () async {
    var now = base;
    var refreshed = 0;
    final gate = Completer<void>();
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => now,
      refresher: (_) async {
        refreshed++;
        await gate.future;
        return token(access: 'a2');
      },
    );
    await session.signIn(token());
    now = base.add(const Duration(hours: 2));

    final f1 = session.accessToken();
    final f2 = session.accessToken();
    final f3 = session.accessToken();
    gate.complete();

    expect(await Future.wait([f1, f2, f3]), ['a2', 'a2', 'a2']);
    expect(refreshed, 1); // single-flighted
  });

  test('a non-expiring token is never refreshed', () async {
    var refreshed = 0;
    final session = AuthSession(
      store: InMemoryTokenStore(),
      now: () => base.add(const Duration(days: 365)),
      refresher: (_) async {
        refreshed++;
        return token(access: 'a2');
      },
    );
    await session.signIn(token(ttl: null)); // never expires

    expect(await session.accessToken(), 'a1');
    expect(refreshed, 0);
  });

  test('authHeaders returns Bearer when signed in, empty when out', () async {
    final session = AuthSession(store: InMemoryTokenStore(), now: () => base);
    expect(await session.authHeaders(), isEmpty);

    await session.signIn(token());
    expect(await session.authHeaders(), {'authorization': 'Bearer a1'});

    await session.signOut();
    expect(await session.accessToken(), isNull);
  });
}
