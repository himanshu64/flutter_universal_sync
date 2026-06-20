import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_supabase/flutter_universal_sync_supabase.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  SyncQueueEntry entry(SyncOperation op) => SyncQueueEntry(
        id: 'q1',
        table: 'things',
        entityId: 't1',
        operation: op,
        payload: const {'id': 't1', 'name': 'a'},
        createdAt: DateTime.utc(2026, 1, 1),
      );

  SupabaseSyncAdapter adapter(MockClient c) => SupabaseSyncAdapter(
        url: Uri.parse('https://proj.supabase.co'),
        anonKey: 'anon-key',
        client: c,
      );

  test('insert → POST /rest/v1 with merge-duplicates + apikey', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('[]', 201);
    }));
    await a.pushChange(entry(SyncOperation.insert));
    expect(req.method, 'POST');
    expect(req.url.path, '/rest/v1/things');
    expect(req.headers['apikey'], 'anon-key');
    expect(req.headers['prefer'], contains('merge-duplicates'));
  });

  test('update → PATCH with id=eq filter', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('[]', 200);
    }));
    await a.pushChange(entry(SyncOperation.update));
    expect(req.method, 'PATCH');
    expect(req.url.queryParameters['id'], 'eq.t1');
  });

  test('delete → PATCH (soft-delete tombstone)', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('[]', 200);
    }));
    await a.pushChange(entry(SyncOperation.delete));
    expect(req.method, 'PATCH');
    expect(req.url.queryParameters['id'], 'eq.t1');
  });

  test('uses the token callback for the bearer when present', () async {
    late http.Request req;
    final a = SupabaseSyncAdapter(
      url: Uri.parse('https://proj.supabase.co'),
      anonKey: 'anon',
      token: () => 'user-jwt',
      client: MockClient((r) async {
        req = r;
        return http.Response('[]', 201);
      }),
    );
    await a.pushChange(entry(SyncOperation.insert));
    expect(req.headers['authorization'], 'Bearer user-jwt');
  });

  test('push non-2xx → SyncPushException', () async {
    final a = adapter(MockClient((r) async => http.Response('no', 401)));
    expect(() => a.pushChange(entry(SyncOperation.insert)),
        throwsA(isA<SyncPushException>()));
  });

  test('push transport error → SyncPushException', () async {
    final a = adapter(MockClient((r) async => throw Exception('down')));
    expect(() => a.pushChange(entry(SyncOperation.update)),
        throwsA(isA<SyncPushException>()));
  });

  test('pull returns rows; since adds an or= filter', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response(
          jsonEncode([
            {'id': '1'},
          ]),
          200);
    }));
    final rows = await a.pullChanges('things', DateTime.utc(2026, 1, 1));
    expect(rows, hasLength(1));
    expect(req.url.queryParameters['or'], contains('updated_at.gt.'));
  });

  test('pull without since omits the filter', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('[]', 200);
    }));
    await a.pullChanges('things', null);
    expect(req.url.queryParameters.containsKey('or'), isFalse);
  });

  test('pull non-2xx → SyncPullException', () async {
    final a = adapter(MockClient((r) async => http.Response('no', 500)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('pull transport error → SyncPullException', () async {
    final a = adapter(MockClient((r) async => throw Exception('down')));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('pull non-array body → SyncPullException', () async {
    final a = adapter(MockClient((r) async => http.Response('{}', 200)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('constructs its own client and close() works', () {
    SupabaseSyncAdapter(url: Uri.parse('https://p.supabase.co'), anonKey: 'k')
        .close();
  });
}
