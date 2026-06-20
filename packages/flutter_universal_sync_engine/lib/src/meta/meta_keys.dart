/// Engine-defined keys used in the `_sync_meta` KV table. Internal to
/// the engine package; consumers do not read these directly.
class MetaKeys {
  MetaKeys._();

  /// Returns the per-table pull cursor key, e.g. `pull_cursor:users`.
  /// Cursor value is a `DateTime.toIso8601String()` of the most recent
  /// `updated_at` seen in any successful pull for that table.
  static String pullCursor(String table) => 'pull_cursor:$table';
}
