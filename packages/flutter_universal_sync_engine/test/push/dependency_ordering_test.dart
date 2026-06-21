import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:flutter_universal_sync_engine/testing.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';

void main() {
  SyncQueueEntry entry(String id, String table, String entityId, int seconds) =>
      SyncQueueEntry(
        id: id,
        table: table,
        entityId: entityId,
        operation: SyncOperation.insert,
        payload: {'id': entityId},
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)),
      );

  test(
    'defers an entry while its dependency entity has unsynced work',
    () async {
      final local = InMemoryAdapter();
      final remote = FakeRemoteSyncAdapter();
      final pipeline = PushPipeline(
        localDb: local,
        remote: remote,
        clock: FakeClock(),
        backoff: defaultBackoff,
        // The task depends on the project entity.
        dependencies: (e) => e.entityId == 't1' ? {'p1'} : <String>{},
      );
      await local.enqueueSync(entry('qp', 'projects', 'p1', 0));
      await local.enqueueSync(entry('qt', 'tasks', 't1', 1));

      // First drain: project still pending → task held; only project pushes.
      await pipeline.drain();
      expect(remote.pushed.map((e) => e.id), ['qp']);

      // Project is now synced → task becomes eligible.
      await pipeline.drain();
      expect(remote.pushed.map((e) => e.id), ['qp', 'qt']);
    },
  );

  test('without a dependencies callback, both push in one drain', () async {
    final local = InMemoryAdapter();
    final remote = FakeRemoteSyncAdapter();
    final pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: FakeClock(),
      backoff: defaultBackoff,
    );
    await local.enqueueSync(entry('qp', 'projects', 'p1', 0));
    await local.enqueueSync(entry('qt', 'tasks', 't1', 1));
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['qp', 'qt']);
  });
}
