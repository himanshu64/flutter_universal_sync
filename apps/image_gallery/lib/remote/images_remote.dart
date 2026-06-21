import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';
import 'package:http/http.dart' as http;

/// Our [RestSyncAdapter] extended with a single limited `/photos` fetch
/// (jsonplaceholder has 5000; we want the first 100), normalized for the
/// local store.
class ImagesRemote extends RestSyncAdapter {
  ImagesRemote._(this._http) : super(baseUrl: _base, client: _http);

  factory ImagesRemote({http.Client? client}) =>
      ImagesRemote._(client ?? http.Client());

  final http.Client _http;
  static final _base = Uri.parse('https://jsonplaceholder.typicode.com');

  Future<List<Map<String, dynamic>>> fetchPhotos({int limit = 100}) async {
    final uri = _base.replace(
      pathSegments: ['photos'],
      queryParameters: {'_limit': '$limit'},
    );
    final res = await _http.get(uri);
    if (res.statusCode >= 400) {
      throw SyncPullException(table: 'photos', cause: 'HTTP ${res.statusCode}');
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
