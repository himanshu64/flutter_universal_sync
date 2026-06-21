import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

/// A REST [RemoteSyncAdapter] over plain HTTP/JSON.
///
/// Maps each [SyncQueueEntry] to a RESTful request against
/// `<baseUrl>/<table>`:
///
/// - [SyncOperation.insert] → `POST   <baseUrl>/<table>`        (body = payload)
/// - [SyncOperation.update] → `PUT    <baseUrl>/<table>/<id>`   (body = payload)
/// - [SyncOperation.delete] → `DELETE <baseUrl>/<table>/<id>`
///
/// Pull is `GET <baseUrl>/<table>?since=<ms>`; the response is either a JSON
/// array of rows, or a JSON object with a `rows` array. Supply [headers] for
/// auth. Non-2xx responses raise [SyncPushException] / [SyncPullException].
class RestSyncAdapter implements RemoteSyncAdapter {
  /// Creates an adapter targeting [baseUrl]. Inject [client] in tests and
  /// [headers] for per-request auth headers.
  RestSyncAdapter({
    required this.baseUrl,
    http.Client? client,
    Map<String, String> Function()? headers,
    this.idempotencyKeys = true,
  })  : _client = client ?? http.Client(),
        _headers = headers;

  /// Root URL of the backend, e.g. `https://api.example.com/v1`.
  final Uri baseUrl;

  /// When `true` (default), each push sends an `Idempotency-Key` header set to
  /// the (stable) queue-entry id. A re-push after a crash carries the same key,
  /// so an idempotency-aware backend deduplicates it instead of double-applying.
  final bool idempotencyKeys;

  final http.Client _client;
  final Map<String, String> Function()? _headers;

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    final headers = {
      ...?_headers?.call(),
      'content-type': 'application/json',
      if (idempotencyKeys) 'idempotency-key': entry.id,
    };
    http.Response res;
    try {
      switch (entry.operation) {
        case SyncOperation.insert:
          res = await _client.post(
            _collection(entry.table),
            headers: headers,
            body: jsonEncode(entry.payload),
          );
        case SyncOperation.update:
          res = await _client.put(
            _resource(entry.table, entry.entityId),
            headers: headers,
            body: jsonEncode(entry.payload),
          );
        case SyncOperation.delete:
          res = await _client.delete(
            _resource(entry.table, entry.entityId),
            headers: headers,
          );
      }
    } catch (e) {
      throw SyncPushException(queueEntryId: entry.id, cause: e);
    }
    if (res.statusCode >= 400) {
      throw SyncPushException(
        queueEntryId: entry.id,
        cause: 'HTTP ${res.statusCode}: ${res.body}',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    final uri = since == null
        ? _collection(table)
        : _collection(table).replace(queryParameters: {
            'since': since.toUtc().millisecondsSinceEpoch.toString(),
          });
    http.Response res;
    try {
      res = await _client.get(uri, headers: {...?_headers?.call()});
    } catch (e) {
      throw SyncPullException(table: table, cause: e);
    }
    if (res.statusCode >= 400) {
      throw SyncPullException(
        table: table,
        cause: 'HTTP ${res.statusCode}: ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    final List<dynamic> rows;
    if (decoded is List) {
      rows = decoded;
    } else if (decoded is Map && decoded['rows'] is List) {
      rows = decoded['rows'] as List;
    } else {
      throw SyncPullException(
        table: table,
        cause: 'expected a JSON array or {"rows": [...]}, got '
            '${decoded.runtimeType}',
      );
    }
    return rows
        .cast<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Uri _collection(String table) => baseUrl.replace(
        pathSegments: [
          ...baseUrl.pathSegments.where((s) => s.isNotEmpty),
          table,
        ],
      );

  Uri _resource(String table, String id) => baseUrl.replace(
        pathSegments: [
          ...baseUrl.pathSegments.where((s) => s.isNotEmpty),
          table,
          id,
        ],
      );

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
