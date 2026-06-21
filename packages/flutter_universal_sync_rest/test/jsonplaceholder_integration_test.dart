@Tags(['integration'])
library;

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';
import 'package:test/test.dart';

/// Live checks against https://jsonplaceholder.typicode.com (a fake REST API).
/// Run with `dart test -t integration`. jsonplaceholder accepts writes but does
/// not persist them, so these verify request/response handling, not round-trip.
void main() {
  final adapter = RestSyncAdapter(
    baseUrl: Uri.parse('https://jsonplaceholder.typicode.com'),
  );

  tearDownAll(adapter.close);

  test('pull /posts returns a non-empty list of rows', () async {
    final rows = await adapter.pullChanges('posts', null);
    expect(rows, isNotEmpty);
    expect(rows.first['id'], isNotNull);
    expect(rows.first['title'], isA<String>());
  });

  test('insert POSTs to /posts without error', () async {
    await adapter.pushChange(SyncQueueEntry(
      id: 'q-int',
      table: 'posts',
      entityId: '',
      operation: SyncOperation.insert,
      payload: const {'title': 'foo', 'body': 'bar', 'userId': 1},
      createdAt: DateTime.utc(2026, 1, 1),
    ));
  });

  test('update PUTs to /posts/1 without error', () async {
    await adapter.pushChange(SyncQueueEntry(
      id: 'q-int-2',
      table: 'posts',
      entityId: '1',
      operation: SyncOperation.update,
      payload: const {'id': 1, 'title': 'updated', 'body': 'b', 'userId': 1},
      createdAt: DateTime.utc(2026, 1, 1),
    ));
  });

  test('delete DELETEs /posts/1 without error', () async {
    await adapter.pushChange(SyncQueueEntry(
      id: 'q-int-3',
      table: 'posts',
      entityId: '1',
      operation: SyncOperation.delete,
      payload: const {},
      createdAt: DateTime.utc(2026, 1, 1),
    ));
  });
}
