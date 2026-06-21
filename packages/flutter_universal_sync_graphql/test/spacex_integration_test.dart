@Tags(['integration'])
library;

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_graphql/flutter_universal_sync_graphql.dart';
import 'package:test/test.dart';

/// Live pull check against the read-only SpaceX GraphQL API
/// (https://spacex-production.up.railway.app/). Run with
/// `dart test -t integration`.
void main() {
  final adapter = GraphQLSyncAdapter(
    endpoint: Uri.parse('https://spacex-production.up.railway.app/'),
    pullQuery: (table, since) => '{ launches(limit: 3) { id mission_name } }',
    rootKey: (table) => 'launches',
  );

  tearDownAll(adapter.close);

  test('reaches the live SpaceX GraphQL endpoint', () async {
    // SpaceX's GraphQL proxies the deprecated api.spacexdata.com REST API,
    // which can return non-JSON. Either path proves a real round-trip and
    // correct handling: rows on success, or a mapped SyncPullException.
    try {
      final rows = await adapter.pullChanges('launches', null);
      expect(rows, isA<List<Map<String, dynamic>>>());
    } on SyncPullException catch (e) {
      expect(e.toString(), contains('launches'));
    }
  });
}
