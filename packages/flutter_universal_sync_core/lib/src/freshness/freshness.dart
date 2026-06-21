import '../schema/sync_columns.dart';

/// How fresh a single locally-cached row is relative to the server.
enum RowFreshness {
  /// Confirmed pushed to (or pulled from) the server — authoritative.
  synced,

  /// Has an un-pushed local edit — optimistic, not yet acknowledged.
  pending,
}

/// Classifies a row's freshness from its sync metadata columns.
///
/// Lets a UI mark optimistic (not-yet-synced) rows — a pending badge, a muted
/// style — so users can tell confirmed data from in-flight edits.
RowFreshness rowFreshness(Map<String, dynamic> row) {
  final synced =
      row[SyncColumns.isSynced] == 1 || row[SyncColumns.syncStatus] == 'synced';
  return synced ? RowFreshness.synced : RowFreshness.pending;
}

/// Decides whether locally-cached data is too old to trust, given when it was
/// last synced.
///
/// Offline-first reads come from the local cache and may lag the server. Pair
/// this with a per-table "last synced at" timestamp to drive a refresh, a
/// "showing cached data" banner, or a forced pull.
class StalenessPolicy {
  /// Data older than [maxAge] (or never synced) is considered stale.
  const StalenessPolicy(this.maxAge);

  /// Maximum age before cached data is treated as stale.
  final Duration maxAge;

  /// Whether data last synced at [lastSyncedAt] is stale at [now]. A null
  /// [lastSyncedAt] (never synced) is always stale.
  bool isStale(DateTime? lastSyncedAt, DateTime now) =>
      lastSyncedAt == null || now.difference(lastSyncedAt) > maxAge;
}
