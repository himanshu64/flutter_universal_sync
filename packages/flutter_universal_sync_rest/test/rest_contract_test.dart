import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Demonstrates the shared `runRemoteSyncAdapterContract` against a real
/// `RestSyncAdapter`, backed by an in-memory fake REST server (a `MockClient`).
/// This is the template for verifying any custom `RemoteSyncAdapter`.
class _RestHarness implements RemoteAdapterHarness {
  _RestHarness() {
    _adapter = RestSyncAdapter(
      baseUrl: Uri.parse('https://api.test/v1'),
      client: MockClient(_handle),
    );
  }

  late final RestSyncAdapter _adapter;
  final Map<String, Map<String, dynamic>> _rows = {}; // id -> row

  Future<http.Response> _handle(http.Request r) async {
    // baseUrl is /v1, so a collection path is /v1/<table> and a resource path
    // is /v1/<table>/<id>.
    final segments = r.url.pathSegments;
    final id = segments.length >= 3 ? segments.last : null;

    switch (r.method) {
      case 'GET': // pull the collection
        final since = int.tryParse(r.url.queryParameters['since'] ?? '');
        final rows = _rows.values.where(
          (row) =>
              since == null || ((row[SyncColumns.updatedAt] as int?) ?? 0) > since,
        );
        return http.Response(jsonEncode(rows.toList()), 200);
      case 'POST': // insert
        final row = jsonDecode(r.body) as Map<String, dynamic>;
        _rows[row[SyncColumns.id] as String] = row;
        return http.Response('{}', 201);
      case 'PUT': // update
        _rows[id!] = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      case 'DELETE':
        _rows.remove(id);
        return http.Response('', 204);
      default:
        return http.Response('not found', 404);
    }
  }

  @override
  RemoteSyncAdapter get adapter => _adapter;

  @override
  Future<void> seed(String table, List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      _rows[row[SyncColumns.id] as String] = Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> backendRows(String table) async =>
      _rows.values.map((r) => Map<String, dynamic>.from(r)).toList();

  @override
  Future<void> dispose() async => _adapter.close();
}

void main() {
  runRemoteSyncAdapterContract(
    adapterName: 'RestSyncAdapter',
    newHarness: _RestHarness.new,
  );
}
