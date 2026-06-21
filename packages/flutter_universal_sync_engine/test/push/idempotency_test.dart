import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import 'package:flutter_universal_sync_engine/testing.dart';

/// Documents the trade-off in spec §6.4: the push and the mark-synced
/// are not bundled in one transaction. If the process dies between the
/// two, the next drain re-pushes. Most adapters' operations are
/// idempotent (PUT, DELETE, server-side UPSERT), which is why we accept
/// the trade-off.
void main() {
  test('mark-synced not running causes a re-push next drain', () async {
    final local = _CrashAfterPushAdapter();
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
      ),
    );

    local.crashOnNextMarkSynced = true;
    // Pipeline should swallow the crash and surface a failed entry.
    final firstDrain = await pipeline.drain();
    expect(remote.pushed, hasLength(1));
    expect(firstDrain.succeeded, 0);

    // Re-enable mark-synced and drain again. The same q1 should re-push.
    local.crashOnNextMarkSynced = false;
    await pipeline.drain();
    expect(remote.pushed, hasLength(2));
    expect(remote.pushed.last.id, 'q1');
  });
}

class _CrashAfterPushAdapter extends InMemoryAdapter {
  bool crashOnNextMarkSynced = false;

  @override
  Future<void> markSynced(String queueEntryId) async {
    if (crashOnNextMarkSynced) {
      crashOnNextMarkSynced = false;
      throw StateError('simulated crash between push and mark-synced');
    }
    return super.markSynced(queueEntryId);
  }
}
