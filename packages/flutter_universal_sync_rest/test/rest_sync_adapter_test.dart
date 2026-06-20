import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  SyncQueueEntry entry(SyncOperation op) => SyncQueueEntry(
        id: 'q1',
        table: 'posts',
        entityId: 'p1',
        operation: op,
        payload: const {'id': 'p1', 'title': 't'},
        createdAt: DateTime.utc(2026, 1, 1),
      );

  RestSyncAdapter adapter(MockClient client) => RestSyncAdapter(
        baseUrl: Uri.parse('https://api.test/v1'),
        client: client,
      );

  group('pushChange', () {
    test('insert → POST to the collection with JSON body', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('{}', 201);
      }));
      await a.pushChange(entry(SyncOperation.insert));
      expect(req.method, 'POST');
      expect(req.url.toString(), 'https://api.test/v1/posts');
      expect(jsonDecode(req.body)['title'], 't');
      expect(req.headers['content-type'], contains('application/json'));
    });

    test('update → PUT to the resource', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('{}', 200);
      }));
      await a.pushChange(entry(SyncOperation.update));
      expect(req.method, 'PUT');
      expect(req.url.toString(), 'https://api.test/v1/posts/p1');
    });

    test('delete → DELETE to the resource', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('', 204);
      }));
      await a.pushChange(entry(SyncOperation.delete));
      expect(req.method, 'DELETE');
      expect(req.url.toString(), 'https://api.test/v1/posts/p1');
    });

    test('sends auth headers from the headers callback', () async {
      late http.Request req;
      final a = RestSyncAdapter(
        baseUrl: Uri.parse('https://api.test/v1'),
        client: MockClient((r) async {
          req = r;
          return http.Response('{}', 201);
        }),
        headers: () => {'authorization': 'Bearer xyz'},
      );
      await a.pushChange(entry(SyncOperation.insert));
      expect(req.headers['authorization'], 'Bearer xyz');
    });

    test('non-2xx → SyncPushException', () async {
      final a = adapter(MockClient((r) async => http.Response('nope', 500)));
      expect(
        () => a.pushChange(entry(SyncOperation.insert)),
        throwsA(isA<SyncPushException>()),
      );
    });

    test('transport error → SyncPushException', () async {
      final a = adapter(MockClient((r) async => throw Exception('offline')));
      expect(
        () => a.pushChange(entry(SyncOperation.update)),
        throwsA(isA<SyncPushException>()),
      );
    });
  });

  group('pullChanges', () {
    test('parses a JSON array of rows', () async {
      final a = adapter(MockClient((r) async => http.Response(
            jsonEncode([
              {'id': '1', 'name': 'a'},
              {'id': '2', 'name': 'b'},
            ]),
            200,
          )));
      final rows = await a.pullChanges('posts', null);
      expect(rows, hasLength(2));
      expect(rows.first['name'], 'a');
    });

    test('parses a {"rows": [...]} envelope', () async {
      final a = adapter(MockClient((r) async => http.Response(
            jsonEncode({
              'rows': [
                {'id': '1'},
              ],
            }),
            200,
          )));
      expect(await a.pullChanges('posts', null), hasLength(1));
    });

    test('passes since as a millis query parameter', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('[]', 200);
      }));
      final since = DateTime.utc(2026, 1, 1);
      await a.pullChanges('posts', since);
      expect(
        req.url.queryParameters['since'],
        since.millisecondsSinceEpoch.toString(),
      );
    });

    test('non-2xx → SyncPullException', () async {
      final a = adapter(MockClient((r) async => http.Response('no', 404)));
      expect(
        () => a.pullChanges('posts', null),
        throwsA(isA<SyncPullException>()),
      );
    });

    test('unexpected body shape → SyncPullException', () async {
      final a = adapter(MockClient((r) async => http.Response('42', 200)));
      expect(
        () => a.pullChanges('posts', null),
        throwsA(isA<SyncPullException>()),
      );
    });
  });

  test('close() is callable', () {
    adapter(MockClient((r) async => http.Response('[]', 200))).close();
  });
}
