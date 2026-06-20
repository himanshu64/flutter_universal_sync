import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
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

  test('no pending → resolver NOT called, server wins', () async {
    final calls = <String>[];
    final config = TableConfig(
      conflictResolver: _RecordingResolver(calls),
    );
    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'u1',
          'name': 'remote',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 200,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ],
    ];

    await pipeline.pullTable('users', config);

    expect(calls, isEmpty);
    final row = await local.getById('users', 'u1');
    expect(row!['name'], 'remote');
  });

  test('local has pending → resolver IS called with (local, remote)', () async {
    await local.upsert('users', {
      SyncColumns.id: 'u1',
      'name': 'local',
      SyncColumns.createdAt: 100,
      SyncColumns.updatedAt: 150,
      SyncColumns.deletedAt: null,
      SyncColumns.isSynced: 0,
      SyncColumns.syncStatus: 'pending',
    });
    await local.enqueueSync(
      SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1', 'name': 'local'},
        createdAt: DateTime.utc(2026, 1, 1, 12),
      ),
    );
    final calls = <String>[];
    final config = TableConfig(
      conflictResolver: _RecordingResolver(calls, picks: 'remote'),
    );

    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'u1',
          'name': 'remote',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 250,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ],
    ];

    await pipeline.pullTable('users', config);

    expect(calls, ['called with local=local remote=remote']);
    // Resolver picked "remote" → row is now remote.
    final row = await local.getById('users', 'u1');
    expect(row!['name'], 'remote');
    // Queue entry payload was rewritten to the merged map.
    final pending = await local.pendingSyncEntries();
    expect(pending.single.payload['name'], 'remote');
  });

  test('remote row for unknown entity → upsert as insert', () async {
    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'new',
          'name': 'fresh',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 100,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ],
    ];

    await pipeline.pullTable('users', const TableConfig());

    expect(await local.getById('users', 'new'), isNotNull);
  });
}

class _RecordingResolver implements ConflictResolver {
  _RecordingResolver(this.calls, {this.picks = 'local'});
  final List<String> calls;
  final String picks; // 'local' or 'remote'

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    calls.add('called with local=${local['name']} remote=${remote['name']}');
    return picks == 'remote' ? remote : local;
  }
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
