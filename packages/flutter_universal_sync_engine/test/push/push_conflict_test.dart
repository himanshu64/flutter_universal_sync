import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:flutter_universal_sync_engine/testing.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';

class _ThrowingResolver implements ConflictResolver {
  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) =>
      throw StateError('resolver blew up');
}

void main() {
  SyncQueueEntry entry(Map<String, dynamic> payload) => SyncQueueEntry(
        id: 'q1',
        table: 'things',
        entityId: 't1',
        operation: SyncOperation.update,
        payload: payload,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  SyncPushException conflict({Map<String, dynamic>? serverState}) =>
      SyncPushException(
        queueEntryId: 'q1',
        cause: 'HTTP 409',
        isConflict: true,
        serverState: serverState,
      );

  final localPayload = {
    SyncColumns.id: 't1',
    SyncColumns.updatedAt: 1000,
    'name': 'local',
  };
  final serverRow = {
    SyncColumns.id: 't1',
    SyncColumns.updatedAt: 9000, // newer → LWW picks the server
    'name': 'server',
  };

  Future<(InMemoryAdapter, FakeRemoteSyncAdapter, PushDrainResult)> drainWith(
    FakeRemoteSyncAdapter remote, {
    ConflictResolver Function(String)? resolverFor,
  }) async {
    final local = InMemoryAdapter();
    await local.upsert('things', {...localPayload, SyncColumns.isSynced: 0});
    await local.enqueueSync(entry(localPayload));
    final pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: FakeClock(),
      backoff: defaultBackoff,
      conflictResolverFor: resolverFor,
    );
    return (local, remote, await pipeline.drain());
  }

  test('resolves a 409, rewrites the payload, re-pushes, and marks synced',
      () async {
    final remote = FakeRemoteSyncAdapter()
      ..pushOutcomes.addAll([conflict(serverState: serverRow), null]);

    final (local, _, result) = await drainWith(
      remote,
      resolverFor: (_) => const LastWriteWinsResolver(),
    );

    expect(result.succeeded, 1);
    expect(remote.pushed.length, 2); // original + merged re-push
    expect(remote.pushed.last.payload['name'], 'server'); // LWW merged
    expect(await local.pendingSyncEntries(), isEmpty); // acknowledged
    final row = await local.getById('things', 't1');
    expect(row?['name'], 'server'); // converged to the merged row
  });

  test('a 409 without serverState falls through to backoff', () async {
    final remote = FakeRemoteSyncAdapter()..pushOutcomes.add(conflict());

    final (local, _, result) = await drainWith(
      remote,
      resolverFor: (_) => const LastWriteWinsResolver(),
    );

    expect(result.failed, isNotEmpty);
    expect(remote.pushed.length, 1); // no re-push
    expect(await local.pendingSyncEntries(), isNotEmpty); // still queued
  });

  test('a resolver that throws fails the entry (no re-push)', () async {
    final remote = FakeRemoteSyncAdapter()
      ..pushOutcomes.add(conflict(serverState: serverRow));

    final (_, _, result) = await drainWith(
      remote,
      resolverFor: (_) => _ThrowingResolver(),
    );

    expect(result.failed.single.error, isA<ConflictResolutionException>());
    expect(remote.pushed.length, 1);
  });

  test('a second push failure after resolution backs off', () async {
    final remote = FakeRemoteSyncAdapter()
      ..pushOutcomes.addAll([
        conflict(serverState: serverRow),
        Exception('still failing'),
      ]);

    final (local, _, result) = await drainWith(
      remote,
      resolverFor: (_) => const LastWriteWinsResolver(),
    );

    expect(result.failed, isNotEmpty);
    expect(remote.pushed.length, 2); // attempted the re-push
    expect(await local.pendingSyncEntries(), isNotEmpty);
  });

  test('without a resolver, a 409 is just a normal failure', () async {
    final remote = FakeRemoteSyncAdapter()
      ..pushOutcomes.add(conflict(serverState: serverRow));

    final (_, _, result) = await drainWith(remote); // no resolverFor

    expect(result.failed, isNotEmpty);
    expect(remote.pushed.length, 1);
  });
}
