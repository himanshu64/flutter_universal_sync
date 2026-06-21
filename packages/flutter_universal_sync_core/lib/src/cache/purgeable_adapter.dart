/// Optional capability a [LocalDatabaseAdapter] may also implement to support
/// cache eviction. It is **separate** from the core adapter contract, so
/// adapters opt in without breaking the others.
///
/// Implementations hard-remove **synced** rows only — never pending
/// (unsynced) rows, which still hold un-pushed local changes.
abstract class PurgeableAdapter {
  /// Hard-removes synced rows from [table] to bound the local cache, returning
  /// the number removed.
  ///
  /// - [olderThan]: only purge synced rows whose `updated_at` is before this.
  /// - [keepLatest]: always retain the [keepLatest] most-recently-updated
  ///   synced rows, purging older synced ones.
  ///
  /// With both `null` this is a no-op (a policy must be given).
  Future<int> purgeSynced(String table, {DateTime? olderThan, int? keepLatest});
}
