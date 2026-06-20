import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('entry with future next_retry_at is skipped', () async {
    final local = InMemoryAdapter();
    final remote = FakeRemoteSyncAdapter();
    final clock = FakeClock();
    final pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: clock,
      backoff: defaultBackoff,
    );
    await local.enqueueSync(
      SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1'},
        createdAt: clock.now(),
        nextRetryAt: clock.now().add(const Duration(minutes: 1)),
        retryCount: 1,
      ),
    );

    await pipeline.drain();
    expect(remote.pushed, isEmpty);

    clock.advance(const Duration(minutes: 2));
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1']);
  });
}
