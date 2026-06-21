import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import '../entities/post.dart';
import '../remote/paged_posts_remote.dart';

/// VIPER Interactor — the business logic. Fetches the next page from the
/// remote, caches it locally (offline-capable), and returns the running list.
/// Knows nothing about widgets.
class PaginationInteractor {
  PaginationInteractor({required this.remote, required this.local});

  final PagedPostsRemote remote;
  final LocalDatabaseAdapter local;
  static const table = 'posts';
  static const pageSize = 20;

  int _page = 0;
  bool hasMore = true;

  Future<List<Post>> cached() async {
    final rows = await local.getAll(table)
      ..sort((a, b) => _idOf(a).compareTo(_idOf(b)));
    return rows.map(Post.fromRow).toList();
  }

  /// Pulls the next page, caches it, and returns the full cached list.
  Future<List<Post>> loadNextPage() async {
    if (!hasMore) return cached();
    _page++;
    final rows = await remote.fetchPage(table, page: _page, limit: pageSize);
    if (rows.length < pageSize) hasMore = false;
    if (rows.isNotEmpty) {
      await local.transaction(() async {
        for (final r in rows) {
          await local.upsert(table, r);
        }
      });
    }
    return cached();
  }

  int _idOf(Map<String, dynamic> r) =>
      int.tryParse('${r[SyncColumns.id] ?? r['id']}') ?? 0;
}
