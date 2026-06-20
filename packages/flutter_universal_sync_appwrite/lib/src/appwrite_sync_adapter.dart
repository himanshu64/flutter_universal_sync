import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

/// An Appwrite [RemoteSyncAdapter] over the Databases REST API.
///
/// Each domain table maps to an Appwrite collection of the same id.
///
/// - insert → `POST   <endpoint>/databases/<db>/collections/<table>/documents`
///   with `{documentId, data}`
/// - update/delete → `PATCH .../documents/<id>` with `{data}`
///   (delete sends the soft-delete tombstone payload)
/// - pull → `GET .../documents?queries[]=greaterThan("updated_at", <ms>)` →
///   `{documents: [...]}`, unwrapped.
///
/// Provide [apiKey] (server) or [jwt] (client session). Non-2xx responses raise
/// `SyncPushException` / `SyncPullException`.
class AppwriteSyncAdapter implements RemoteSyncAdapter {
  /// Creates an adapter for the Appwrite project at [endpoint].
  AppwriteSyncAdapter({
    required this.endpoint,
    required this.projectId,
    required this.databaseId,
    String Function()? apiKey,
    String Function()? jwt,
    http.Client? client,
  })  : _apiKey = apiKey,
        _jwt = jwt,
        _client = client ?? http.Client();

  /// Appwrite API endpoint, e.g. `https://cloud.appwrite.io/v1`.
  final Uri endpoint;

  /// The Appwrite project id.
  final String projectId;

  /// The database id the collections live in.
  final String databaseId;

  final String Function()? _apiKey;
  final String Function()? _jwt;
  final http.Client _client;

  Map<String, String> _headers() => {
        'x-appwrite-project': projectId,
        if (_apiKey != null) 'x-appwrite-key': _apiKey(),
        if (_jwt != null) 'x-appwrite-jwt': _jwt(),
        'content-type': 'application/json',
      };

  Uri _documents(String table, {String? id, Map<String, dynamic>? query}) {
    return endpoint.replace(
      pathSegments: [
        ...endpoint.pathSegments.where((s) => s.isNotEmpty),
        'databases',
        databaseId,
        'collections',
        table,
        'documents',
        if (id != null) id,
      ],
      queryParameters: query,
    );
  }

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    http.Response res;
    try {
      switch (entry.operation) {
        case SyncOperation.insert:
          res = await _client.post(
            _documents(entry.table),
            headers: _headers(),
            body: jsonEncode({
              'documentId': entry.entityId,
              'data': entry.payload,
            }),
          );
        case SyncOperation.update:
        case SyncOperation.delete:
          res = await _client.patch(
            _documents(entry.table, id: entry.entityId),
            headers: _headers(),
            body: jsonEncode({'data': entry.payload}),
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
    final queries = <String>['orderAsc("updated_at")'];
    if (since != null) {
      queries.insert(
        0,
        'greaterThan("updated_at", ${since.toUtc().millisecondsSinceEpoch})',
      );
    }
    http.Response res;
    try {
      res = await _client.get(
        _documents(table, query: {'queries[]': queries}),
        headers: _headers(),
      );
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
    if (decoded is! Map || decoded['documents'] is! List) {
      throw SyncPullException(
        table: table,
        cause: 'expected {"documents": [...]}',
      );
    }
    return (decoded['documents'] as List)
        .cast<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
