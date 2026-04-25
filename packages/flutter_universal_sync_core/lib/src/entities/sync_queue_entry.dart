import 'sync_operation.dart';

/// One queued local mutation awaiting push to a remote backend.
///
/// Per-op queue: each [insert]/[update]/[delete] on the repository produces
/// one entry. The entry is persisted locally in the same transaction as the
/// domain row write (see `LocalDatabaseAdapter.transaction`).
///
/// [retryCount] and [lastError] are populated by the sync engine
/// (`flutter_universal_sync_engine`, Plan 2); Plan 1 only defines them.
class SyncQueueEntry {
  /// Creates a queue entry. [retryCount] defaults to 0; [synced] to false;
  /// [lastError] to null.
  const SyncQueueEntry({
    required this.id,
    required this.table,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.synced = false,
  });

  /// UUID of this queue row. Distinct from [entityId].
  final String id;

  /// Name of the target user table.
  final String table;

  /// Identifier of the row being synced.
  final String entityId;

  /// Which mutation this entry represents.
  final SyncOperation operation;

  /// Full row snapshot at enqueue time. Not a diff.
  final Map<String, dynamic> payload;

  /// When the entry was enqueued (wall-clock UTC).
  final DateTime createdAt;

  /// How many push attempts have already failed for this entry.
  final int retryCount;

  /// Error message from the most recent failed push, if any.
  final String? lastError;

  /// `true` after the remote adapter has acknowledged the push.
  final bool synced;

  /// Returns a copy with the listed fields replaced.
  SyncQueueEntry copyWith({
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    int? retryCount,
    String? lastError,
    bool? synced,
  }) =>
      SyncQueueEntry(
        id: id,
        table: table,
        entityId: entityId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError ?? this.lastError,
        synced: synced ?? this.synced,
      );

  /// Serializes for persistence. `operation` becomes a stable name string;
  /// `createdAt` becomes millisecondsSinceEpoch; `synced` becomes 0/1.
  Map<String, dynamic> toMap() => {
        'id': id,
        'table': table,
        'entity_id': entityId,
        'operation': operation.name,
        'payload': payload,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'retry_count': retryCount,
        'last_error': lastError,
        'synced': synced ? 1 : 0,
      };

  /// Reconstructs from a map produced by [toMap].
  factory SyncQueueEntry.fromMap(Map<String, dynamic> m) => SyncQueueEntry(
        id: m['id'] as String,
        table: m['table'] as String,
        entityId: m['entity_id'] as String,
        operation: SyncOperation.values.byName(m['operation'] as String),
        payload: Map<String, dynamic>.from(m['payload'] as Map<dynamic, dynamic>),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
        retryCount: (m['retry_count'] as int?) ?? 0,
        lastError: m['last_error'] as String?,
        synced: (m['synced'] as int?) == 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueEntry &&
          id == other.id &&
          table == other.table &&
          entityId == other.entityId &&
          operation == other.operation &&
          _mapEquals(payload, other.payload) &&
          createdAt == other.createdAt &&
          retryCount == other.retryCount &&
          lastError == other.lastError &&
          synced == other.synced;

  @override
  int get hashCode => Object.hash(
        id,
        table,
        entityId,
        operation,
        Object.hashAll(
          payload.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        createdAt,
        retryCount,
        lastError,
        synced,
      );
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
