import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

/// Builds the GraphQL query string used to pull a table's delta.
typedef PullQueryBuilder = String Function(String table, DateTime? since);

/// Builds the GraphQL mutation string used to push one queue entry.
typedef PushMutationBuilder = String Function(SyncQueueEntry entry);

/// A GraphQL [RemoteSyncAdapter] over a single `POST <endpoint>` with a
/// `{query, variables}` body.
///
/// GraphQL schemas vary per backend, so you supply the query/mutation
/// builders. [pullQuery] returns a query whose result, under
/// `data[rootKey(table)]`, is the list of rows. [pushMutation] is optional —
/// omit it for a read-only endpoint (push then raises [SyncPushException]).
class GraphQLSyncAdapter implements RemoteSyncAdapter {
  /// Creates an adapter for [endpoint].
  GraphQLSyncAdapter({
    required this.endpoint,
    required this.pullQuery,
    this.pushMutation,
    String Function(String table)? rootKey,
    http.Client? client,
    Map<String, String> Function()? headers,
  })  : _rootKey = rootKey ?? ((t) => t),
        _client = client ?? http.Client(),
        _headers = headers;

  /// The GraphQL endpoint, e.g. `https://api.example.com/graphql`.
  final Uri endpoint;

  /// Builds the pull query for a table.
  final PullQueryBuilder pullQuery;

  /// Builds the push mutation for an entry, or `null` for a read-only API.
  final PushMutationBuilder? pushMutation;

  final String Function(String table) _rootKey;
  final http.Client _client;
  final Map<String, String> Function()? _headers;

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    final build = pushMutation;
    if (build == null) {
      throw SyncPushException(
        queueEntryId: entry.id,
        cause: 'GraphQL adapter is read-only (no pushMutation configured)',
      );
    }
    final Map<String, dynamic> body;
    try {
      body = await _post(build(entry));
    } catch (e) {
      if (e is SyncPushException) rethrow;
      throw SyncPushException(queueEntryId: entry.id, cause: e);
    }
    final errors = body['errors'];
    if (errors != null) {
      throw SyncPushException(queueEntryId: entry.id, cause: '$errors');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    Map<String, dynamic> body;
    try {
      body = await _post(pullQuery(table, since));
    } catch (e) {
      if (e is SyncPullException) rethrow;
      throw SyncPullException(table: table, cause: e);
    }
    final errors = body['errors'];
    if (errors != null) {
      throw SyncPullException(table: table, cause: '$errors');
    }
    final data = body['data'];
    if (data is! Map) {
      throw SyncPullException(table: table, cause: 'no data in response');
    }
    final list = data[_rootKey(table)];
    if (list is! List) {
      throw SyncPullException(
        table: table,
        cause: 'expected a list at data.${_rootKey(table)}',
      );
    }
    return list
        .cast<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<Map<String, dynamic>> _post(String document) async {
    final res = await _client.post(
      endpoint,
      headers: {...?_headers?.call(), 'content-type': 'application/json'},
      body: jsonEncode({'query': document}),
    );
    if (res.statusCode >= 400) {
      throw StateError('HTTP ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
