import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late FakeClock clock;
  late PushPipeline pipeline;

  setUp(() {
    local = InMemoryAdapter();
    remote = FakeRemoteSyncAdapter();
    clock = FakeClock();
    pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: clock,
      backoff: defaultBackoff,
    );
  });

  Future<void> enqueue(
    String qid,
    String entityId, {
    int seconds = 0,
    SyncOperation op = SyncOperation.update,
  }) =>
      local.enqueueSync(
        SyncQueueEntry(
          id: qid,
          table: 'users',
          entityId: entityId,
          operation: op,
          payload: {'id': entityId, 'q': qid},
          createdAt: clock.now().add(Duration(seconds: seconds)),
        ),
      );

  test('pushes all entries when all succeed', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u2', seconds: 1);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2']);
    expect(result.succeeded, 2);
    expect(result.failed, isEmpty);
  });

  test('within a group, stops after first failure', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u1', seconds: 1);
    await enqueue('q3', 'u1', seconds: 2);
    remote.pushOutcomes.addAll([null, Exception('boom')]);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2']); // q3 not attempted
    expect(result.succeeded, 1);
    expect(result.failed.single.entry.id, 'q2');
  });

  test('failure in group A does NOT stop group B', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u2', seconds: 1);
    await enqueue('q3', 'u2', seconds: 2);
    remote.pushOutcomes.addAll([Exception('boom-1'), null, null]);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2', 'q3']);
    expect(result.succeeded, 2);
    expect(result.failed.single.entry.id, 'q1');
  });

  test('groups are processed in earliest-created-at order', () async {
    await enqueue('q-late', 'u1', seconds: 5);
    await enqueue('q-early', 'u2', seconds: 0);
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q-early', 'q-late']);
  });

  test('within a group, entries push in created_at order', () async {
    await enqueue('q-second', 'u1', seconds: 1);
    await enqueue('q-first', 'u1', seconds: 0);
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q-first', 'q-second']);
  });

  test('successful pushes are marked synced', () async {
    await enqueue('q1', 'u1');
    await pipeline.drain();
    final pending = await local.pendingSyncEntries();
    expect(pending, isEmpty);
  });

  test('failed entry is recorded with retry_count + next_retry_at', () async {
    await enqueue('q1', 'u1');
    remote.pushOutcomes.add(Exception('http 500'));
    await pipeline.drain();
    final pending = await local.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(pending.first.retryCount, 1);
    expect(pending.first.lastError, contains('http 500'));
    expect(pending.first.nextRetryAt, isNotNull);
    // first failure → 1s backoff under defaultBackoff
    expect(
      pending.first.nextRetryAt!.difference(clock.now()),
      const Duration(seconds: 1),
    );
  });
}
