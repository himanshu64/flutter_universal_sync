import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_appwrite/flutter_universal_sync_appwrite.dart';
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

  AppwriteSyncAdapter adapter(MockClient c) => AppwriteSyncAdapter(
        endpoint: Uri.parse('https://cloud.appwrite.io/v1'),
        projectId: 'proj',
        databaseId: 'db',
        apiKey: () => 'server-key',
        client: c,
      );

  test('insert → POST documents with {documentId, data} + project header',
      () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('{}', 201);
    }));
    await a.pushChange(entry(SyncOperation.insert));
    expect(req.method, 'POST');
    expect(req.url.path, '/v1/databases/db/collections/things/documents');
    expect(req.headers['x-appwrite-project'], 'proj');
    expect(req.headers['x-appwrite-key'], 'server-key');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['documentId'], 't1');
    expect((body['data'] as Map)['name'], 'a');
  });

  test('update → PATCH documents/<id>', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('{}', 200);
    }));
    await a.pushChange(entry(SyncOperation.update));
    expect(req.method, 'PATCH');
    expect(req.url.path, endsWith('/documents/t1'));
  });

  test('delete → PATCH documents/<id> (tombstone)', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response('{}', 200);
    }));
    await a.pushChange(entry(SyncOperation.delete));
    expect(req.method, 'PATCH');
    expect(req.url.path, endsWith('/documents/t1'));
  });

  test('uses a client JWT header when provided', () async {
    late http.Request req;
    final a = AppwriteSyncAdapter(
      endpoint: Uri.parse('https://cloud.appwrite.io/v1'),
      projectId: 'proj',
      databaseId: 'db',
      jwt: () => 'jwt-token',
      client: MockClient((r) async {
        req = r;
        return http.Response('{}', 201);
      }),
    );
    await a.pushChange(entry(SyncOperation.insert));
    expect(req.headers['x-appwrite-jwt'], 'jwt-token');
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

  test('pull unwraps {documents:[...]}; since adds greaterThan query',
      () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response(
        jsonEncode({
          'documents': [
            {'id': '1'},
          ],
        }),
        200,
      );
    }));
    final rows = await a.pullChanges('things', DateTime.utc(2026, 1, 1));
    expect(rows, hasLength(1));
    expect(
      req.url.queryParametersAll['queries[]']!
          .any((q) => q.contains('greaterThan')),
      isTrue,
    );
  });

  test('pull without since omits greaterThan', () async {
    late http.Request req;
    final a = adapter(MockClient((r) async {
      req = r;
      return http.Response(jsonEncode({'documents': <dynamic>[]}), 200);
    }));
    await a.pullChanges('things', null);
    expect(
      req.url.queryParametersAll['queries[]']!
          .any((q) => q.contains('greaterThan')),
      isFalse,
    );
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

  test('pull unexpected body → SyncPullException', () async {
    final a = adapter(MockClient((r) async => http.Response('[]', 200)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('constructs its own client and close() works', () {
    AppwriteSyncAdapter(
      endpoint: Uri.parse('https://cloud.appwrite.io/v1'),
      projectId: 'p',
      databaseId: 'd',
    ).close();
  });
}
