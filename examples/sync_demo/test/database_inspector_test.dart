import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_demo/dev/database_inspector.dart';

void main() {
  late DatabaseInspectorServer server;
  late Uri url;
  late HttpClient client;

  setUp(() async {
    server = DatabaseInspectorServer(
      tables: const ['things', '_sync_meta'],
      query: (table) async => switch (table) {
        'things' => [
          {'id': 't1', 'name': 'apple', 'deleted_at': null},
        ],
        _ => [
          {'key': 'pull_cursor:things', 'value': '2026-01-01T00:00:00.000Z'},
        ],
      },
      runSql: (sql) async => [
        {'matched': sql},
      ],
    );
    url = await server.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close();
    await server.stop();
  });

  Future<Map<String, dynamic>> getJson(String path, [String? query]) async {
    final req = await client.getUrl(url.replace(path: path, query: query));
    final res = await req.close();
    return jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  }

  test('/data returns every table with its rows', () async {
    final body = await getJson('/data');
    expect(body.keys, containsAll(['things', '_sync_meta']));
    expect((body['things'] as List).single['name'], 'apple');
    expect(
      (body['_sync_meta'] as List).single['value'],
      '2026-01-01T00:00:00.000Z',
    );
  });

  test('/ serves the Database Inspector HTML shell', () async {
    final req = await client.getUrl(url);
    final res = await req.close();
    final html = await res.transform(utf8.decoder).join();
    expect(html, contains('Database Inspector'));
    expect(res.headers.contentType?.mimeType, 'text/html');
  });

  test('/query runs a read-only SELECT', () async {
    final body = await getJson('/query', 'sql=${Uri.encodeQueryComponent('SELECT 1')}');
    expect(body['error'], isNull);
    expect((body['rows'] as List).single['matched'], 'SELECT 1');
  });

  test('/query rejects a non-SELECT statement', () async {
    final body =
        await getJson('/query', 'sql=${Uri.encodeQueryComponent('DELETE FROM things')}');
    expect(body['rows'], isNull);
    expect(body['error'], contains('read-only'));
  });

  test('/query rejects stacked statements', () async {
    final body = await getJson(
      '/query',
      'sql=${Uri.encodeQueryComponent('SELECT 1; DROP TABLE things')}',
    );
    expect(body['error'], contains('single statement'));
  });
}
