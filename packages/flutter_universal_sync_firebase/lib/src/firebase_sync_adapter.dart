import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:http/http.dart' as http;

import 'firestore_value_codec.dart';

/// A Cloud Firestore [RemoteSyncAdapter] over the Firestore REST API.
///
/// Each domain table maps to a Firestore collection of the same id; each row
/// is a document whose id is the row id.
///
/// - insert/update → `PATCH <docs>/<table>/<id>` with `{fields: ...}` (upsert)
/// - delete → `PATCH` with the soft-delete tombstone fields
/// - pull → `POST <docs>:runQuery` with a `structuredQuery` filtering
///   `updated_at > since`, decoding each returned document's typed fields.
///
/// Pure Dart over REST so it needs no Firebase SDK; supply a Firebase ID
/// token via [idToken] (re-read per request). Non-2xx responses raise
/// `SyncPushException` / `SyncPullException`.
class FirebaseSyncAdapter implements RemoteSyncAdapter {
  /// Creates an adapter for Firestore project [projectId].
  FirebaseSyncAdapter({
    required this.projectId,
    required String Function() idToken,
    this.databaseId = '(default)',
    http.Client? client,
  })  : _idToken = idToken,
        _client = client ?? http.Client();

  /// The Firebase/GCP project id.
  final String projectId;

  /// The Firestore database id (almost always `(default)`).
  final String databaseId;

  final String Function() _idToken;
  final http.Client _client;

  String get _documents =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/'
      '$databaseId/documents';

  Map<String, String> _headers() => {
        'authorization': 'Bearer ${_idToken()}',
        'content-type': 'application/json',
      };

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    // insert / update / delete all upsert the document; delete carries the
    // soft-delete tombstone payload.
    http.Response res;
    try {
      res = await _client.patch(
        Uri.parse('$_documents/${entry.table}/${entry.entityId}'),
        headers: _headers(),
        body: jsonEncode({
          'fields': FirestoreValueCodec.encodeFields(entry.payload),
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
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    final structuredQuery = <String, dynamic>{
      'from': [
        {'collectionId': table},
      ],
      'orderBy': [
        {
          'field': {'fieldPath': 'updated_at'},
        },
      ],
      if (since != null)
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'updated_at'},
            'op': 'GREATER_THAN',
            'value': FirestoreValueCodec.encodeValue(
              since.toUtc().millisecondsSinceEpoch,
            ),
          },
        },
    };
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_documents:runQuery'),
        headers: _headers(),
        body: jsonEncode({'structuredQuery': structuredQuery}),
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
    if (decoded is! List) {
      throw SyncPullException(table: table, cause: 'expected a runQuery array');
    }
    final rows = <Map<String, dynamic>>[];
    for (final element in decoded) {
      if (element is Map && element['document'] is Map) {
        final doc = element['document'] as Map<String, dynamic>;
        final fields = doc['fields'] as Map<String, dynamic>? ?? const {};
        rows.add(FirestoreValueCodec.decodeFields(fields));
      }
    }
    return rows;
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
