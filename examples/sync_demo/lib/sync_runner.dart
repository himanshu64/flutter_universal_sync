import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import 'adapters/rest_adapter.dart';
import 'adapters/sqflite_adapter.dart';

/// Tiny manual sync driver. Drains the local queue (stop-on-first-failure
/// per the spec, Q7), then pulls deltas since the last watermark.
///
/// Prefigures `flutter_universal_sync_engine` (Plan 2). The real engine
/// will add connectivity gating, retry/backoff, dead-lettering, and
/// resolve-on-conflict logic — but this demo skips those to keep the
/// flow visible.
class SyncRunner {
  SyncRunner({required this.local, required this.remote});

  final SqfliteSyncAdapter local;
  final RestSyncAdapter remote;

  Future<SyncOutcome> sync(String table) async {
    final pushed = await _drainQueue();
    final pulled = await _pull(table);
    return SyncOutcome(pushed: pushed, pulled: pulled);
  }

  Future<int> _drainQueue() async {
    int pushed = 0;
    final entries = await local.pendingSyncEntries();
    for (final entry in entries) {
      try {
        await remote.pushChange(entry);
        await local.markSynced(entry.id);
        // Mirror to the entity row so the UI can show "synced".
        await local.update(entry.table, entry.entityId, {
          'is_synced': 1,
          'sync_status': 'synced',
        });
        pushed++;
      } on SyncPushException catch (e) {
        await local.recordSyncFailure(entry.id, e.message);
        // Plan 1 / Q7: stop on first failure. Surface to caller.
        rethrow;
      }
    }
    return pushed;
  }

  Future<int> _pull(String table) async {
    final since = await local.lastSync(table);
    final result = await remote.pullChangesWithTime(table, since);

    int merged = 0;
    await local.transaction(() async {
      for (final row in result.rows) {
        final id = row['id'] as String;
        final existing = await local.getById(table, id);
        // Cast the remote row through the adapter's local schema. Mark as
        // synced since it came directly from the server.
        final localShape = <String, dynamic>{
          ...row,
          'is_synced': 1,
          'sync_status': 'synced',
        };
        if (existing == null) {
          await local.insert(table, localShape);
        } else {
          await local.update(table, id, localShape);
        }
        merged++;
      }
      await local.setLastSync(table, result.serverTime);
    });
    return merged;
  }
}

class SyncOutcome {
  const SyncOutcome({required this.pushed, required this.pulled});
  final int pushed;
  final int pulled;
}
