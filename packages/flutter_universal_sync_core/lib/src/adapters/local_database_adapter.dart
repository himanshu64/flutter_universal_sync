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
  /// `null` limit returns every pending entry.
  Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit});

  /// Marks the given queue entry as successfully synced.
  Future<void> markSynced(String queueEntryId);

  /// Records a failed push attempt: stores [error] on the entry's
  /// `last_error`. Plan 1 does not increment `retry_count`; Plan 2 will.
  Future<void> recordSyncFailure(String queueEntryId, String error);

  /// Runs [action] inside a single atomic transaction. If [action] throws,
  /// every write performed during the callback is rolled back.
  Future<T> transaction<T>(Future<T> Function() action);

  /// Verifies every table in [tables] includes the required sync columns.
  /// Throws [SchemaValidationException] listing missing columns on mismatch.
  Future<void> validateSchema(List<String> tables);
}
