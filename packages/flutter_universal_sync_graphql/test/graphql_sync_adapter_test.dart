import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_graphql/flutter_universal_sync_graphql.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  SyncQueueEntry entry() => SyncQueueEntry(
        id: 'q1',
        table: 'things',
        entityId: 't1',
        operation: SyncOperation.insert,
        payload: const {'id': 't1'},
        createdAt: DateTime.utc(2026, 1, 1),
      );

  GraphQLSyncAdapter pull(MockClient c) => GraphQLSyncAdapter(
        endpoint: Uri.parse('https://api.test/graphql'),
        pullQuery: (table, since) => '{ $table { id } }',
        client: c,
      );

  test('pull extracts the list at data[table]', () async {
    final a = pull(MockClient((r) async => http.Response(
          jsonEncode({
            'data': {
              'things': [
                {'id': '1'},
                {'id': '2'},
              ],
            },
          }),
          200,
        )));
    final rows = await a.pullChanges('things', null);
    expect(rows, hasLength(2));
    expect(rows.first['id'], '1');
  });

  test('pull surfaces GraphQL errors as SyncPullException', () async {
    final a = pull(MockClient((r) async => http.Response(
          jsonEncode({
            'errors': [
              {'message': 'boom'},
            ],
          }),
          200,
        )));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('pull on a non-list root → SyncPullException', () async {
    final a = pull(MockClient((r) async => http.Response(
        jsonEncode({
          'data': <String, dynamic>{'things': 5},
        }),
        200)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('push posts the mutation and succeeds', () async {
    late http.Request req;
    final a = GraphQLSyncAdapter(
      endpoint: Uri.parse('https://api.test/graphql'),
      pullQuery: (t, s) => '',
      pushMutation: (e) => 'mutation { insert(id: "${e.entityId}") { id } }',
      client: MockClient((r) async {
        req = r;
        return http.Response(jsonEncode({'data': <String, dynamic>{}}), 200);
      }),
    );
    await a.pushChange(entry());
    expect(jsonDecode(req.body)['query'], contains('mutation'));
  });

  test('push is read-only without a pushMutation', () async {
    final a = pull(MockClient((r) async => http.Response('{}', 200)));
    expect(() => a.pushChange(entry()), throwsA(isA<SyncPushException>()));
  });

  test('push surfaces GraphQL errors as SyncPushException', () async {
    final a = GraphQLSyncAdapter(
      endpoint: Uri.parse('https://api.test/graphql'),
      pullQuery: (t, s) => '',
      pushMutation: (e) => 'mutation {}',
      client: MockClient((r) async => http.Response(
            jsonEncode({
              'errors': [
                {'message': 'denied'},
              ],
            }),
            200,
          )),
    );
    expect(() => a.pushChange(entry()), throwsA(isA<SyncPushException>()));
  });

  test('push maps an HTTP error to SyncPushException', () async {
    final a = GraphQLSyncAdapter(
      endpoint: Uri.parse('https://api.test/graphql'),
      pullQuery: (t, s) => '',
      pushMutation: (e) => 'mutation {}',
      client: MockClient((r) async => http.Response('<html>', 502)),
    );
    expect(() => a.pushChange(entry()), throwsA(isA<SyncPushException>()));
  });

  test('pull maps an HTTP error to SyncPullException', () async {
    final a = pull(MockClient((r) async => http.Response('<html>', 500)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('pull with no data and no errors → SyncPullException', () async {
    final a = pull(MockClient((r) async => http.Response('{}', 200)));
    expect(
        () => a.pullChanges('things', null), throwsA(isA<SyncPullException>()));
  });

  test('constructs its own client when none is injected', () {
    GraphQLSyncAdapter(
      endpoint: Uri.parse('https://api.test/graphql'),
      pullQuery: (t, s) => '',
    ).close();
  });

  test('close() is callable', () {
    pull(MockClient((r) async => http.Response('{}', 200))).close();
  });
}
