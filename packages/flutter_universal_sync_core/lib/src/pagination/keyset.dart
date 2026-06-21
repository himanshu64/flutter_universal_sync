import '../schema/sync_columns.dart';
import 'page.dart';

int _compareValues(Object? a, Object? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // nulls sort last
  if (b == null) return -1;
  if (a is num && b is num) return a.compareTo(b);
  return Comparable.compare(a as Comparable, b as Comparable);
}

/// Applies keyset pagination to an in-memory [source] of rows.
///
/// Shared by the in-memory and Hive adapters (stores without a query engine).
/// Rows are ordered by [orderBy] then `id`, sliced after the [after] cursor,
/// and capped at [limit]. The returned [PageResult.nextCursor] is non-null only
/// when a full page was produced (more rows may remain).
PageResult paginateRows(
  Iterable<Map<String, dynamic>> source, {
  required int limit,
  required String orderBy,
  required bool descending,
  required PageCursor? after,
}) {
  int order(Map<String, dynamic> a, Map<String, dynamic> b) {
    final c = _compareValues(a[orderBy], b[orderBy]);
    final byId = c != 0
        ? c
        : (a[SyncColumns.id] as String).compareTo(b[SyncColumns.id] as String);
    return descending ? -byId : byId;
  }

  final sorted = source.toList()..sort(order);
  Iterable<Map<String, dynamic>> page = sorted;
  if (after != null) {
    page = sorted.where((r) {
      final c = _compareValues(r[orderBy], after.value);
      if (c != 0) return descending ? c < 0 : c > 0;
      final t = (r[SyncColumns.id] as String).compareTo(after.id);
      return descending ? t < 0 : t > 0;
    });
  }

  final taken =
      page.take(limit).map((r) => Map<String, dynamic>.from(r)).toList();
  final next = taken.length == limit
      ? PageCursor(
          value: taken.last[orderBy],
          id: taken.last[SyncColumns.id] as String,
        )
      : null;
  return PageResult(rows: taken, nextCursor: next);
}
