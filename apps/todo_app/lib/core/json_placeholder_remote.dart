import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_rest/flutter_universal_sync_rest.dart';

/// A [RestSyncAdapter] for https://jsonplaceholder.typicode.com.
///
/// jsonplaceholder rows have integer ids and no sync metadata, so this
/// normalizes pulled rows into the schema the engine + local adapter expect
/// (string `id`, `created_at`/`updated_at` derived from the id, synced flags).
/// Push uses the base adapter as-is (jsonplaceholder fakes writes).
class JsonPlaceholderRemote extends RestSyncAdapter {
  JsonPlaceholderRemote()
      : super(baseUrl: Uri.parse('https://jsonplaceholder.typicode.com'));

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    final rows = await super.pullChanges(table, since);
    return rows.map(_normalize).toList();
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> r) {
    final rawId = r['id'];
    final ms = (rawId is int ? rawId : int.tryParse('$rawId') ?? 0) * 1000;
    return {
      ...r,
      SyncColumns.id: '$rawId',
      SyncColumns.createdAt: ms,
      SyncColumns.updatedAt: ms,
      SyncColumns.deletedAt: null,
      SyncColumns.isSynced: 1,
      SyncColumns.syncStatus: 'synced',
    };
  }
}
