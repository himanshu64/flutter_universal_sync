/// An opaque keyset cursor marking the last row of a page.
///
/// Keyset (a.k.a. seek) pagination anchors on the *values* of the last row
/// rather than a numeric offset, so concurrent inserts and deletes before the
/// cursor cannot shift the window — the cause of duplicated or skipped rows
/// ("stale reads") under offset pagination.
class PageCursor {
  /// Creates a cursor at [value] of the ordering column with [id] as tiebreak.
  const PageCursor({required this.value, required this.id});

  /// Value of the `orderBy` column for the last returned row.
  final Object? value;

  /// Id of the last returned row, breaking ties on equal [value].
  final String id;
}

/// One page of rows plus the cursor needed to fetch the next page.
class PageResult {
  /// Creates a page of [rows] with [nextCursor] (`null` when exhausted).
  const PageResult({required this.rows, required this.nextCursor});

  /// The rows in this page, in the requested order.
  final List<Map<String, dynamic>> rows;

  /// Cursor to pass as `after` for the next page, or `null` if this was the
  /// last page.
  final PageCursor? nextCursor;

  /// Whether another page may exist.
  bool get hasMore => nextCursor != null;
}
