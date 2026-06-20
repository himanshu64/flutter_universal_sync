import '../entities/sync_queue_entry.dart';
// Imported solely so dartdoc resolves the [SchemaValidationException] reference.
// ignore: unused_import
import '../errors/sync_errors.dart';

/// Port every local database (sqflite, drift, hive, objectbox) implements.
///
/// The interface is Map-based for DB agnosticism — the repository layer
/// (Plan 13) is responsible for mapping to/from typed entities.
///
/// **Atomicity.** [transaction] must be a real atomic transaction: the
/// domain-row write + [enqueueSync] enqueueing of the corresponding queue
/// entry must either both succeed or both fail. Partial writes across
/// crashes cause silent sync loss.
///
/// **Soft delete.** [delete] never hard-removes the row; it sets
/// `deleted_at` to `DateTime.now().toUtc().millisecondsSinceEpoch`. Hard
/// removal is the sync engine's concern (future — not Plan 1).
///
/// **Schema ownership.** Users own their table definitions. Adapters do
/// **not** create tables. [validateSchema] is called at init to confirm
/// every required sync column is present, throwing
/// [SchemaValidationException] on a mismatch.
abstract class LocalDatabaseAdapter {
  /// Opens the underlying database. Must be called exactly once.
  Future<void> init();

  /// Releases underlying resources. Safe to call multiple times.
  Future<void> close();

  /// Inserts a row. Throws [StateError] if a row with the same id exists.
  /// Caller supplies all sync metadata fields; the adapter does not
  /// populate them.
  Future<void> insert(String table, Map<String, dynamic> data);

  /// Patches the row with matching id — keys in [data] are written; keys
  /// absent from [data] are unchanged. Caller must include `updated_at`
  /// in [data]. Throws [StateError] if the row does not exist.
  Future<void> update(String table, String id, Map<String, dynamic> data);

  /// Soft-deletes the row: sets `deleted_at` to the current UTC time.
  /// Throws [StateError] if the row does not exist.
  Future<void> delete(String table, String id);

  /// Inserts the row if no row with the same `id` exists, otherwise
  /// patches the existing row with the keys in [data]. Soft-delete
  /// column on [data] is honoured (the engine uses [upsert] to apply
  /// pulled tombstones).
  ///
  /// Caller supplies all sync metadata fields; the adapter does not
  /// populate them. Atomic with respect to [transaction].
  ///
  /// Added in 0.2.0 for the engine's pull pipeline.
  Future<void> upsert(String table, Map<String, dynamic> data);

  /// Reads the value for [key] from the engine's `_sync_meta` KV table,
  /// or `null` if the key does not exist. Added in 0.2.0.
  Future<String?> getMeta(String key);

  /// Inserts or replaces the value for [key] in `_sync_meta`. Atomic
  /// with respect to [transaction]; rolled back on throw. Added in 0.2.0.
  Future<void> setMeta(String key, String value);

  /// Removes [key] from `_sync_meta`. No-op if the key does not exist.
  /// Atomic with respect to [transaction]. Added in 0.2.0.
  Future<void> deleteMeta(String key);

  /// Returns unsynced queue entries for the row identified by
  /// (`table`, `entityId`), ordered by `created_at` ASC. Used by the
  /// engine's pull pipeline to detect pending local edits that conflict
  /// with an incoming remote row. Added in 0.2.0.
  Future<List<SyncQueueEntry>> pendingForEntity(String table, String entityId);

  /// Returns the row with the given id, or `null` if it does not exist.
  /// Soft-deleted rows are returned (inspect `deleted_at` to detect).
  Future<Map<String, dynamic>?> getById(String table, String id);

  /// Returns all rows from [table]. Default behaviour filters out
  /// soft-deleted rows (`deleted_at IS NULL`). Pass `includeDeleted: true`
  /// for a full listing (e.g. for the sync engine's pull-reconciliation).
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  });

  /// Appends a queue entry. Should only be invoked inside [transaction]
  /// alongside the corresponding domain-table mutation.
  Future<void> enqueueSync(SyncQueueEntry entry);

  /// Returns entries with `synced = false` in insertion order, up to [limit].
  ///
  /// If [readyAt] is non-null, also filters entries to those whose
  /// `next_retry_at` is `null` OR `<= readyAt`. The engine passes its
  /// current clock here to skip backoff-deferred entries. When omitted,
  /// every pending entry is returned regardless of `next_retry_at`
  /// (preserves Plan 1 behaviour).
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  });

  /// Marks the given queue entry as successfully synced.
  Future<void> markSynced(String queueEntryId);

  /// Records a failed push attempt for [queueEntryId].
  ///
  /// 0.2.0 semantics:
  /// - Stores [error] in `last_error`.
  /// - If [incrementRetryCount] (default `true`), increments `retry_count`.
  /// - Writes [nextRetryAt] to the entry's `next_retry_at` column. Pass
  ///   `null` to clear (rare; engine always passes a value when called
  ///   for a real failure).
  ///
  /// Pass `incrementRetryCount: false` and omit [nextRetryAt] to retain
  /// 0.1.0 "just record the error" behaviour. Atomic with [transaction].
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  });

  /// Runs [action] inside a single atomic transaction. If [action] throws,
  /// every write performed during the callback is rolled back.
  Future<T> transaction<T>(Future<T> Function() action);

  /// Verifies every table in [tables] includes the required sync columns.
  /// Throws [SchemaValidationException] listing missing columns on mismatch.
  Future<void> validateSchema(List<String> tables);
}
