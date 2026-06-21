import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../engine/_clock.dart';

/// Result of a single [PushPipeline.drain] invocation. Aggregated by
/// the engine into the next snapshot. Internal to the engine package;
/// not part of the public API.
@internal
class PushDrainResult {
  /// Creates a drain result.
  PushDrainResult({
    required this.succeeded,
    required this.skippedDueToBackoff,
    required this.failed,
  });

  /// Number of entries successfully pushed and marked synced.
  final int succeeded;

  /// Number of pending entries deferred this cycle by their backoff window.
  final int skippedDueToBackoff;

  /// Entries whose push failed this cycle, with the error that stopped them.
  final List<({SyncQueueEntry entry, Object error})> failed;
}

/// Drains the local sync queue. Per-entity serial; cross-entity
/// continuation on failure. See spec §6.
@internal
class PushPipeline {
  /// Creates a push pipeline over [localDb] and [remote].
  PushPipeline({
    required this.localDb,
    required this.remote,
    required this.clock,
    required this.backoff,
    this.dependencies,
    this.conflictResolverFor,
  });

  /// Local store the queue is drained from.
  final LocalDatabaseAdapter localDb;

  /// Remote backend each entry is pushed to.
  final RemoteSyncAdapter remote;

  /// Clock used for backoff deadlines (injected for tests).
  final Clock clock;

  /// Maps a retry count to the delay before the next attempt.
  final Duration Function(int retryCount) backoff;

  /// Optional FK-aware ordering: returns the entity ids an entry depends on.
  /// The entry is **deferred** (held to a later cycle) while any of those
  /// entities still has an unsynced queue entry — so e.g. a `task` insert
  /// waits until its `project` has been acknowledged. Cyclic dependencies are
  /// not resolved (both sides wait); declare acyclic relationships.
  final Set<String> Function(SyncQueueEntry entry)? dependencies;

  /// Resolver lookup for **push-side** conflicts. When a `pushChange` throws a
  /// [SyncPushException] with `isConflict` and a `serverState`, the resolver
  /// for that table merges the local payload with the server's version; the
  /// merged row is applied locally, the queue payload rewritten, and the push
  /// retried once. A second failure falls through to normal backoff.
  final ConflictResolver Function(String table)? conflictResolverFor;

  /// Runs one drain pass and returns its aggregate result.
  Future<PushDrainResult> drain() async {
    final ready = await localDb.pendingSyncEntries(readyAt: clock.now());

    // Compute total pending excluding what we'll attempt this cycle to
    // report skippedDueToBackoff. The set complement of `entries`
    // against the unfiltered queue equals "deferred by backoff".
    final allPending = await localDb.pendingSyncEntries();

    // FK-aware deferral: hold any ready entry whose dependency entities still
    // have unsynced work. Those entries simply remain pending for a later cycle.
    final List<SyncQueueEntry> entries;
    final deps = dependencies;
    if (deps == null) {
      entries = ready;
    } else {
      final pendingEntities = allPending.map((e) => e.entityId).toSet();
      entries = ready.where((e) {
        return !deps(
          e,
        ).any((d) => d != e.entityId && pendingEntities.contains(d));
      }).toList();
    }

    final readyIds = entries.map((e) => e.id).toSet();
    final skipped = allPending.where((e) => !readyIds.contains(e.id)).length;

    // Group by entity_id, ordering entries within each group by
    // createdAt (the order the local mutations happened), and tracking
    // each group's earliest createdAt for outer ordering.
    final groups = <String, List<SyncQueueEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.entityId, () => []).add(entry);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final sortedKeys = groups.keys.toList()
      ..sort(
        (a, b) =>
            groups[a]!.first.createdAt.compareTo(groups[b]!.first.createdAt),
      );

    var succeeded = 0;
    final failed = <({SyncQueueEntry entry, Object error})>[];

    for (final entityId in sortedKeys) {
      for (final entry in groups[entityId]!) {
        try {
          await _push(entry);
        } catch (error) {
          // Real push failure: record it and apply backoff so the entry
          // is deferred until its next_retry_at.
          failed.add((entry: entry, error: error));
          // Best-effort failure record. Swallow errors from the failure
          // path itself so we surface the original push error to the
          // caller and can move on to the next group.
          try {
            await localDb.recordSyncFailure(
              entry.id,
              error.toString(),
              nextRetryAt: clock.now().add(backoff(entry.retryCount)),
            );
          } catch (_) {
            // Ignore: the engine's snapshot will surface lastError.
          }
          break; // stop this group; continue to next group
        }
        // Push succeeded. Acknowledge it locally. If mark-synced throws
        // here (a crash between the two un-bundled steps — spec §6.4),
        // leave the entry pending with NO backoff so the next drain
        // re-pushes immediately. Push operations are idempotent, so the
        // re-push is safe.
        try {
          await localDb.markSynced(entry.id);
          succeeded++;
        } catch (error) {
          failed.add((entry: entry, error: error));
          break; // stop this group; continue to next group
        }
      }
    }

    return PushDrainResult(
      succeeded: succeeded,
      skippedDueToBackoff: skipped,
      failed: failed,
    );
  }

  /// Pushes [entry], resolving a single push-side version conflict if the
  /// adapter reports one (HTTP 409) and a resolver + server state are available.
  /// A conflict resolution that itself fails re-throws so the caller applies
  /// backoff — bounding resolution to one attempt per drain.
  Future<void> _push(SyncQueueEntry entry) async {
    try {
      await remote.pushChange(entry);
    } on SyncPushException catch (e) {
      final resolverFor = conflictResolverFor;
      final server = e.serverState;
      if (!e.isConflict || resolverFor == null || server == null) rethrow;

      final Map<String, dynamic> merged;
      try {
        merged = resolverFor(entry.table).resolve(entry.payload, server);
      } catch (error) {
        throw ConflictResolutionException(
          entityId: entry.entityId,
          cause: error,
        );
      }

      // Converge local state on the merged row, rewrite the queued payload,
      // and re-push once. A second failure propagates to the backoff path.
      await localDb.upsert(entry.table, merged);
      await localDb.rewriteQueuePayload(entry.id, merged);
      await remote.pushChange(entry.copyWith(payload: merged));
    }
  }
}
