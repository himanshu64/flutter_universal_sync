import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

/// A Supabase [RemoteSyncAdapter] over the project's PostgREST endpoint.
///
/// - insert → `POST   <url>/rest/v1/<table>` with `Prefer: resolution=merge-duplicates`
/// - update → `PATCH  <url>/rest/v1/<table>?id=eq.<id>` (body = payload)
/// - delete → `PATCH  <url>/rest/v1/<table>?id=eq.<id>` (body = tombstone payload)
/// - pull   → `GET    <url>/rest/v1/<table>?order=updated_at` filtered on
///   `updated_at`/`deleted_at` > since
///
/// [token] is re-read per request (rotating user JWTs). Non-2xx responses raise
/// `SyncPushException` / `SyncPullException`.
class SupabaseSyncAdapter implements RemoteSyncAdapter {
  /// Creates an adapter for the Supabase project at [url] with [anonKey].
  SupabaseSyncAdapter({
    required this.url,
    required this.anonKey,
    String Function()? token,
    http.Client? client,
  })  : _token = token,
        _client = client ?? http.Client();

  /// Project URL, e.g. `https://abc.supabase.co`.
  final Uri url;

  /// The project `apikey` (anon or service key).
  final String anonKey;

  final String Function()? _token;
  final http.Client _client;

  Map<String, String> _headers() => {
        'apikey': anonKey,
        'authorization': 'Bearer ${_token?.call() ?? anonKey}',
        'content-type': 'application/json',
      };

  Uri _rest(String table, [Map<String, String>? query]) => url.replace(
        pathSegments: [
          ...url.pathSegments.where((s) => s.isNotEmpty),
          'rest',
          'v1',
          table,
        ],
        queryParameters: query,
      );

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    http.Response res;
    try {
      switch (entry.operation) {
        case SyncOperation.insert:
          res = await _client.post(
            _rest(entry.table),
            headers: {..._headers(), 'prefer': 'resolution=merge-duplicates'},
            body: jsonEncode(entry.payload),
          );
        case SyncOperation.update:
        case SyncOperation.delete:
          res = await _client.patch(
            _rest(entry.table, {'id': 'eq.${entry.entityId}'}),
            headers: _headers(),
            body: jsonEncode(entry.payload),
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
    final query = <String, String>{'order': 'updated_at'};
    if (since != null) {
      final iso = since.toUtc().toIso8601String();
      query['or'] = '(updated_at.gt.$iso,deleted_at.gt.$iso)';
    }
    http.Response res;
    try {
      res = await _client.get(_rest(table, query), headers: _headers());
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
    if (decoded is! List) {
      throw SyncPullException(table: table, cause: 'expected a JSON array');
    }
    return decoded
        .cast<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
