import '../entities/sync_queue_entry.dart';

/// Port every remote backend (firebase, supabase, appwrite, graphql, rest)
/// implements.
///
/// Per-op semantics: the sync engine calls [pushChange] once per queue
/// entry in FIFO order. Plan 1's stop-on-first-failure semantics mean a
/// thrown [SyncPushException] halts the current batch; the entry stays
/// queued and will be retried on the next sync cycle.
abstract class RemoteSyncAdapter {
  /// Pushes one queue entry to the backend. Throws [SyncPushException]
  /// (wrapping the cause) on any failure — network, HTTP code, validation,
  /// etc. Success returns normally; the engine then calls `markSynced`
  /// on the local adapter.
  Future<void> pushChange(SyncQueueEntry entry);

  /// Fetches rows for [table] updated after [since]. Passing `null` returns
  /// every row. Implementations should filter with
  /// `updated_at > since OR deleted_at > since` so soft-deletes propagate.
  /// Pagination is adapter-internal. Throws [SyncPullException] on failure.
  Future<List<Map<String, dynamic>>> pullChanges(String table, DateTime? since);
}
