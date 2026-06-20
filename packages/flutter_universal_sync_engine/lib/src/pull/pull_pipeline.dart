import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../engine/table_config.dart';
import '../meta/meta_keys.dart';

/// Pulls deltas for a single table and applies them to the local DB.
/// Invokes [TableConfig.conflictResolver] only when the incoming row's
/// entity has a pending local queue entry. See spec §7.
@internal
class PullPipeline {
  /// Creates a pull pipeline over [localDb] and [remote].
  PullPipeline({required this.localDb, required this.remote});

  /// Local store pulled rows are applied to.
  final LocalDatabaseAdapter localDb;

  /// Remote backend deltas are fetched from.
  final RemoteSyncAdapter remote;

  /// Pulls [table] since its stored cursor and applies each row.
  Future<void> pullTable(String table, TableConfig config) async {
    final cursorStr = await localDb.getMeta(MetaKeys.pullCursor(table));
    final since = cursorStr == null ? null : DateTime.parse(cursorStr);

    final remoteRows = await remote.pullChanges(table, since);
    if (remoteRows.isEmpty) return;

    for (final remoteRow in remoteRows) {
      final entityId = remoteRow[SyncColumns.id] as String;
      await localDb.transaction(() async {
        final localRow = await localDb.getById(table, entityId);
        final pending = await localDb.pendingForEntity(table, entityId);

        if (pending.isEmpty || localRow == null) {
          // No competing local edit (or row didn't exist). Server wins.
          await localDb.upsert(table, remoteRow);
        } else {
          final merged = config.conflictResolver.resolve(localRow, remoteRow);
          await localDb.upsert(table, merged);
          await localDb.rewriteQueuePayload(pending.last.id, merged);
        }
      });
    }

    // Advance cursor only after every per-row apply succeeded.
    final maxUpdatedAt = remoteRows
        .map((r) => (r[SyncColumns.updatedAt] as int?) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maxUpdatedAt > 0) {
      await localDb.setMeta(
        MetaKeys.pullCursor(table),
        DateTime.fromMillisecondsSinceEpoch(maxUpdatedAt, isUtc: true)
            .toIso8601String(),
      );
    }
  }
}
