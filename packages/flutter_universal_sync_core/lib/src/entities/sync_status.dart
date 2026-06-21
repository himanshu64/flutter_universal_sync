/// Lifecycle status of a domain row with respect to remote sync.
///
/// Persisted on every [SyncEntity] via the `sync_status` column. The string
/// [name] is persisted and must remain stable.
enum SyncStatus {
  /// Domain row awaiting initial sync.
  pending,

  /// Domain row is currently syncing.
  syncing,

  /// Domain row has been successfully synced.
  synced,

  /// Domain row sync failed.
  failed,
}
