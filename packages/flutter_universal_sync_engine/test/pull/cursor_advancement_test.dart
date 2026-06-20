import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:flutter_universal_sync_engine/src/pull/pull_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late PullPipeline pipeline;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    pipeline = PullPipeline(localDb: local, remote: remote);
  });

  Map<String, dynamic> remoteRow(String id, int updatedAt) => {
        SyncColumns.id: id,
        'name': id,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 1,
        SyncColumns.syncStatus: 'synced',
      };

  test('cursor advances to max(updated_at) on success', () async {
    remote.pullResponses['users'] = [
      [remoteRow('u1', 200), remoteRow('u2', 350), remoteRow('u3', 300)],
    ];

    await pipeline.pullTable('users', const TableConfig());

    final cursor = await local.getMeta(MetaKeys.pullCursor('users'));
    expect(cursor, isNotNull);
    expect(
      DateTime.parse(cursor!).millisecondsSinceEpoch,
      350,
    );
  });

  test('cursor unchanged when remote returns no rows', () async {
    remote.pullResponses['users'] = [<Map<String, dynamic>>[]];
    await pipeline.pullTable('users', const TableConfig());
    expect(await local.getMeta(MetaKeys.pullCursor('users')), isNull);
  });

  test('cursor passed back as `since` on subsequent pulls', () async {
    remote.pullResponses['users'] = [
      [remoteRow('u1', 1000)],
      [remoteRow('u2', 2000)],
    ];
    await pipeline.pullTable('users', const TableConfig());
    await pipeline.pullTable('users', const TableConfig());

    expect(remote.pullCalls.first.since, isNull);
    expect(
      remote.pullCalls.last.since!.millisecondsSinceEpoch,
      1000,
    );
  });
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
