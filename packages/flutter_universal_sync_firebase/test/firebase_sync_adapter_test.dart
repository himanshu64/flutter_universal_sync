import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_firebase/flutter_universal_sync_firebase.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FirestoreValueCodec', () {
    test('round-trips every supported type', () {
      final row = <String, dynamic>{
        'n': null,
        'b': true,
        'i': 42,
        'd': 3.5,
        's': 'hi',
        'list': [1, 'two', false],
        'map': {'nested': 'x', 'k': 7},
      };
      final encoded = FirestoreValueCodec.encodeFields(row);
      expect((encoded['i'] as Map)['integerValue'], '42');
      expect((encoded['s'] as Map)['stringValue'], 'hi');
      final decoded = FirestoreValueCodec.decodeFields(encoded);
      expect(decoded, row);
    });

    test('encode rejects an unsupported type', () {
      expect(() => FirestoreValueCodec.encodeValue(DateTime.now()),
          throwsArgumentError);
    });

    test('decode rejects an unknown typed value', () {
      expect(() => FirestoreValueCodec.decodeValue({'weirdValue': 1}),
          throwsArgumentError);
    });
  });

  SyncQueueEntry entry(SyncOperation op) => SyncQueueEntry(
        id: 'q1',
        table: 'things',
        entityId: 't1',
        operation: op,
        payload: const {'id': 't1', 'name': 'a', 'n': 5},
        createdAt: DateTime.utc(2026, 1, 1),
      );

  FirebaseSyncAdapter adapter(MockClient c) => FirebaseSyncAdapter(
        projectId: 'proj',
        idToken: () => 'id-token',
        client: c,
      );

  group('pushChange', () {
    test('PATCHes the document path with encoded fields + bearer', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('{}', 200);
      }));
      await a.pushChange(entry(SyncOperation.insert));
      expect(req.method, 'PATCH');
      expect(req.url.toString(), contains('/documents/things/t1'));
      expect(req.headers['authorization'], 'Bearer id-token');
      final fields = (jsonDecode(req.body) as Map)['fields'] as Map;
      expect((fields['name'] as Map)['stringValue'], 'a');
      expect((fields['n'] as Map)['integerValue'], '5');
    });

    test('non-2xx → SyncPushException', () async {
      final a = adapter(MockClient((r) async => http.Response('no', 403)));
      expect(() => a.pushChange(entry(SyncOperation.update)),
          throwsA(isA<SyncPushException>()));
    });

    test('transport error → SyncPushException', () async {
      final a = adapter(MockClient((r) async => throw Exception('down')));
      expect(() => a.pushChange(entry(SyncOperation.delete)),
          throwsA(isA<SyncPushException>()));
    });
  });

  group('pullChanges', () {
    test('POSTs runQuery and decodes documents, skipping non-docs', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response(
          jsonEncode([
            {'readTime': '2026-01-01T00:00:00Z'},
            {
              'document': {
                'name': 'projects/p/.../things/t1',
                'fields': {
                  'id': {'stringValue': 't1'},
                  'name': {'stringValue': 'a'},
                },
              },
            },
          ]),
          200,
        );
      }));
      final rows = await a.pullChanges('things', DateTime.utc(2026, 1, 1));
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'a');
      expect(req.url.toString(), endsWith(':runQuery'));
      final q = (jsonDecode(req.body) as Map)['structuredQuery'] as Map;
      expect(q.containsKey('where'), isTrue);
    });

    test('without since omits the where filter', () async {
      late http.Request req;
      final a = adapter(MockClient((r) async {
        req = r;
        return http.Response('[]', 200);
      }));
      await a.pullChanges('things', null);
      final q = (jsonDecode(req.body) as Map)['structuredQuery'] as Map;
      expect(q.containsKey('where'), isFalse);
    });

    test('non-2xx → SyncPullException', () async {
      final a = adapter(MockClient((r) async => http.Response('no', 500)));
      expect(() => a.pullChanges('things', null),
          throwsA(isA<SyncPullException>()));
    });

    test('transport error → SyncPullException', () async {
      final a = adapter(MockClient((r) async => throw Exception('down')));
      expect(() => a.pullChanges('things', null),
          throwsA(isA<SyncPullException>()));
    });

    test('non-array body → SyncPullException', () async {
      final a = adapter(MockClient((r) async => http.Response('{}', 200)));
      expect(() => a.pullChanges('things', null),
          throwsA(isA<SyncPullException>()));
    });
  });

  test('constructs its own client and close() works', () {
    FirebaseSyncAdapter(projectId: 'p', idToken: () => 't').close();
  });
}
