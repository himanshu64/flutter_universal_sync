import 'package:meta/meta.dart';

import 'engine_status.dart';

/// Immutable snapshot of the sync engine's state at a moment in time.
///
/// The engine emits a new `SyncStateSnapshot` on every transition (start
/// of cycle, end of cycle, error). Late subscribers immediately receive
/// the current snapshot.
@immutable
class SyncStateSnapshot {
  /// Construct directly. Prefer the named factories below.
  const SyncStateSnapshot({
    required this.status,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });

  /// The state at the start of an idle cycle (or initial state).
  factory SyncStateSnapshot.idle({
    required int pendingCount,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.idle,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
      );

  /// The state while a cycle is running.
  factory SyncStateSnapshot.syncing({
    required int pendingCount,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.syncing,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
      );

  /// Terminal state for a cycle that finished with at least one error.
  factory SyncStateSnapshot.error({
    required int pendingCount,
    required String lastError,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.error,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
        lastError: lastError,
      );

  /// Coarse status. See [EngineStatus] for semantics.
  final EngineStatus status;

  /// Number of unsynced queue entries at emission time.
  final int pendingCount;

  /// Last time a cycle completed without errors. Null until the first
  /// successful cycle.
  final DateTime? lastSyncedAt;

  /// Error message from the most recent failed cycle, or null after a
  /// successful cycle.
  final String? lastError;

  /// Returns a copy with the listed fields replaced. Pass
  /// [clearLastError] = `true` to set [lastError] to null (the
  /// idiomatic way to express "this snapshot has cleared the prior
  /// error").
  SyncStateSnapshot copyWith({
    EngineStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearLastError = false,
  }) =>
      SyncStateSnapshot(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStateSnapshot &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          lastSyncedAt == other.lastSyncedAt &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      Object.hash(status, pendingCount, lastSyncedAt, lastError);
}
