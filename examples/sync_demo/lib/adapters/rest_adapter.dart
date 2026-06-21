import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

/// **Demo-grade** REST `RemoteSyncAdapter` targeting the test backend at
/// `examples/test-backend/`.
///
/// This is NOT the production `flutter_universal_sync_rest` package
/// (Plan 12) — it lives here to demonstrate the contract end-to-end.
class RestSyncAdapter implements RemoteSyncAdapter {
  RestSyncAdapter({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Root URL of the backend, e.g. `http://localhost:4567`.
  final Uri baseUrl;
  final http.Client _client;

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    final endpoint = baseUrl.resolve('/sync/${entry.table}');
    http.Response res;
    try {
      res = await _client.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'changes': [
            {
              'operation': entry.operation.name,
              'payload': entry.payload,
            },
          ],
        }),
      );
    } catch (e) {
      throw SyncPushException(queueEntryId: entry.id, cause: e);
    }
    if (res.statusCode >= 400) {
      throw SyncPushException(
        queueEntryId: entry.id,
        cause: 'HTTP ${res.statusCode}: ${res.body}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List).cast<Map<String, dynamic>>();
    if (results.isEmpty) {
      throw SyncPushException(
        queueEntryId: entry.id,
        cause: 'empty results array',
      );
    }
    final first = results.first;
    final status = first['status'] as String?;
    if (status == 'ok') return;
    // 'rejected' or 'error' — surface as push exception for the engine.
    throw SyncPushException(
      queueEntryId: entry.id,
      cause: 'server returned $status: ${first['reason'] ?? '(no reason)'}',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    final qp = since == null
        ? <String, String>{}
        : {'since': since.toUtc().millisecondsSinceEpoch.toString()};
    final endpoint = baseUrl.resolve('/sync/$table').replace(
          queryParameters: qp.isEmpty ? null : qp,
        );
    http.Response res;
    try {
      res = await _client.get(endpoint);
    } catch (e) {
      throw SyncPullException(table: table, cause: e);
    }
    if (res.statusCode >= 400) {
      throw SyncPullException(
        table: table,
        cause: 'HTTP ${res.statusCode}: ${res.body}',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (body['rows'] as List).cast<Map<String, dynamic>>();
    return rows.map(Map<String, dynamic>.from).toList();
  }

  void close() => _client.close();
}
