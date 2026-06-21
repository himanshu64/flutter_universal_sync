import '../schema/sync_columns.dart';
import 'page.dart';

/// Optional capability a [LocalDatabaseAdapter] may also implement to read the
/// local store one page at a time, using **keyset** (seek) pagination.
///
/// Separate from the core adapter contract, so adapters opt in without
/// affecting the others. Keyset pagination is stable under concurrent
/// inserts/deletes (no offset drift), which is what prevents the stale reads —
/// duplicated or skipped rows — that plague `LIMIT/OFFSET` paging.
abstract class PaginatedAdapter {
  /// Returns up to [limit] rows of [table] ordered by [orderBy] (default
  /// `updated_at`), `descending` by default, continuing after the [after]
  /// cursor.
  ///
  /// Pass `after: result.nextCursor` to fetch the following page; a `null`
  /// `nextCursor` means there are no more rows. Soft-deleted rows are excluded
  /// unless [includeDeleted] is set.
  Future<PageResult> getPage(
    String table, {
    int limit = 20,
    String orderBy = SyncColumns.updatedAt,
    bool descending = true,
    PageCursor? after,
    bool includeDeleted = false,
  });
}
