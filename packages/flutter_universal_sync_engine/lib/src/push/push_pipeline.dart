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
  });

  /// Local store the queue is drained from.
  final LocalDatabaseAdapter localDb;

  /// Remote backend each entry is pushed to.
  final RemoteSyncAdapter remote;

  /// Clock used for backoff deadlines (injected for tests).
  final Clock clock;

  /// Maps a retry count to the delay before the next attempt.
  final Duration Function(int retryCount) backoff;

  /// Runs one drain pass and returns its aggregate result.
  Future<PushDrainResult> drain() async {
    final entries = await localDb.pendingSyncEntries(readyAt: clock.now());

    // Compute total pending excluding what we'll attempt this cycle to
    // report skippedDueToBackoff. The set complement of `entries`
    // against the unfiltered queue equals "deferred by backoff".
    final allPending = await localDb.pendingSyncEntries();
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
          await remote.pushChange(entry);
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
}
