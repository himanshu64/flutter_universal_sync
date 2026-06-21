/// Base type for every exception thrown by the flutter_universal_sync family.
sealed class SyncException implements Exception {
  /// Human-readable message.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown by `LocalDatabaseAdapter.validateSchema` when a user-declared
/// table is missing one or more required sync columns.
class SchemaValidationException extends SyncException {
  /// Creates a schema validation exception.
  SchemaValidationException({
    required this.table,
    required List<String> missingColumns,
  }) : missingColumns = List.unmodifiable(missingColumns);

  /// Name of the offending table.
  final String table;

  /// Columns that were absent from the table's schema (read-only).
  final List<String> missingColumns;

  @override
  String get message =>
      'Table $table is missing sync columns: ${missingColumns.join(', ')}';
}

/// Thrown by `RemoteSyncAdapter.pushChange` implementations when a single
/// queue entry fails to push. Plan 1's stop-on-first-failure semantics
/// mean this halts the current sync batch; the entry remains in the queue.
class SyncPushException extends SyncException {
  /// Creates a push exception.
  SyncPushException({required this.queueEntryId, required this.cause});

  /// The queue entry that failed.
  final String queueEntryId;

  /// The underlying failure (network error, HTTP code, etc.).
  final Object cause;

  @override
  String get message =>
      'Failed to push queue entry $queueEntryId: $cause';
}

/// Thrown by `RemoteSyncAdapter.pullChanges` implementations when fetching
/// remote changes for a table fails.
class SyncPullException extends SyncException {
  /// Creates a pull exception.
  SyncPullException({required this.table, required this.cause});

  /// Table whose pull failed.
  final String table;

  /// The underlying failure.
  final Object cause;

  @override
  String get message => 'Failed to pull changes for $table: $cause';
}

/// Thrown when a user-provided `ConflictResolver.resolve` call itself
/// throws — distinguishes resolver bugs from sync-layer failures.
class ConflictResolutionException extends SyncException {
  /// Creates a conflict resolution exception.
  ConflictResolutionException({required this.entityId, required this.cause});

  /// Id of the row whose conflict resolution failed.
  final String entityId;

  /// The underlying failure.
  final Object cause;

  @override
  String get message =>
      'Conflict resolver failed for entity $entityId: $cause';
}
