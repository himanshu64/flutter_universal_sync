import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:flutter_universal_sync_engine/src/pull/pull_pipeline.dart';
import 'package:test/test.dart';

import 'package:flutter_universal_sync_engine/testing.dart';

void main() {
  test('empty remoteRows → no transactions, cursor unchanged', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', const [
        SyncColumns.id,
        SyncColumns.createdAt,
        SyncColumns.updatedAt,
        SyncColumns.deletedAt,
        SyncColumns.isSynced,
        SyncColumns.syncStatus,
      ]);
    final remote = FakeRemoteSyncAdapter()
      ..pullResponses['users'] = [<Map<String, dynamic>>[]];
    final pipeline = PullPipeline(localDb: local, remote: remote);

    await pipeline.pullTable('users', const TableConfig());

    expect(remote.pullCalls, hasLength(1));
    expect(await local.getMeta(MetaKeys.pullCursor('users')), isNull);
  });
}
