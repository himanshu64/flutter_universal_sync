import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_demo/dev/db_viewer.dart';

void main() {
  test('serves table JSON on /data and HTML on /', () async {
    final server = DbViewerServer(
      tables: const ['things', '_sync_meta'],
      query: (table) async => switch (table) {
        'things' => [
          {'id': 't1', 'name': 'apple', 'deleted_at': null},
        ],
        _ => [
          {'key': 'pull_cursor:things', 'value': '2026-01-01T00:00:00.000Z'},
        ],
      },
    );
    final url = await server.start();
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);

    // /data → JSON with both tables and their rows.
    final dataReq = await client.getUrl(url.replace(path: '/data'));
    final dataRes = await dataReq.close();
    final body =
        jsonDecode(await dataRes.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    expect(body.keys, containsAll(['things', '_sync_meta']));
    expect((body['things'] as List).single['name'], 'apple');
    expect(
      (body['_sync_meta'] as List).single['value'],
      '2026-01-01T00:00:00.000Z',
    );

    // / → the HTML shell.
    final htmlReq = await client.getUrl(url);
    final htmlRes = await htmlReq.close();
    final html = await htmlRes.transform(utf8.decoder).join();
    expect(html, contains('sync_demo database'));
    expect(htmlRes.headers.contentType?.mimeType, 'text/html');
  });
}
