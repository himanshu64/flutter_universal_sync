import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';
import 'package:http/http.dart' as http;

/// Our [RestSyncAdapter], extended with jsonplaceholder offset pagination
/// (`?_page=&_limit=`). Reuses one [http.Client] across the base adapter and
/// the [fetchPage] call, and normalizes rows into the sync schema.
class PagedPostsRemote extends RestSyncAdapter {
  PagedPostsRemote._(this._http) : super(baseUrl: _base, client: _http);

  factory PagedPostsRemote({http.Client? client}) =>
      PagedPostsRemote._(client ?? http.Client());

  final http.Client _http;
  static final _base = Uri.parse('https://jsonplaceholder.typicode.com');

  /// Fetches one page of [table], normalized for the local store.
  Future<List<Map<String, dynamic>>> fetchPage(
    String table, {
    required int page,
    int limit = 20,
  }) async {
    final uri = _base.replace(
      pathSegments: [table],
      queryParameters: {'_page': '$page', '_limit': '$limit'},
    );
    final res = await _http.get(uri);
    if (res.statusCode >= 400) {
      throw SyncPullException(table: table, cause: 'HTTP ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List;
    return list.cast<Map<String, dynamic>>().map(_normalize).toList();
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> r) {
    final rawId = r['id'];
    final ms = (rawId is int ? rawId : int.tryParse('$rawId') ?? 0) * 1000;
    return {
      ...r,
      SyncColumns.id: '$rawId',
      SyncColumns.createdAt: ms,
      SyncColumns.updatedAt: ms,
      SyncColumns.deletedAt: null,
      SyncColumns.isSynced: 1,
      SyncColumns.syncStatus: 'synced',
    };
  }
}
