import 'purgeable_adapter.dart';

/// Runs a cache-eviction policy across tables on a [PurgeableAdapter].
///
/// ```dart
/// final evictor = CacheEvictor(local as PurgeableAdapter);
/// await evictor.evict(['photos', 'posts'], maxAge: const Duration(days: 7), maxRows: 500);
/// ```
class CacheEvictor {
  /// Creates an evictor that purges rows from [adapter].
  const CacheEvictor(this.adapter);

  /// The purge-capable local adapter rows are evicted from.
  final PurgeableAdapter adapter;

  /// Evicts synced rows from each of [tables] older than [maxAge] and/or beyond
  /// the newest [maxRows]. Returns the total number of rows removed. [now] is
  /// injectable for tests.
  Future<int> evict(
    List<String> tables, {
    Duration? maxAge,
    int? maxRows,
    DateTime? now,
  }) async {
    final cutoff = maxAge == null
        ? null
        : (now ?? DateTime.now()).toUtc().subtract(maxAge);
    var removed = 0;
    for (final table in tables) {
      removed += await adapter.purgeSynced(
        table,
        olderThan: cutoff,
        keepLatest: maxRows,
      );
    }
    return removed;
  }
}
