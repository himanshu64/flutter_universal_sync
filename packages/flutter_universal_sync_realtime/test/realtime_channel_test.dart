import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_realtime/flutter_universal_sync_realtime.dart';
import 'package:test/test.dart';

/// Flushes pending microtasks/timers so the channel's async loop advances.
Future<void> pump([int turns = 4]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  RealtimeEvent upsert(String id, String name) => RealtimeEvent(
        table: 'things',
        type: RealtimeEventType.upsert,
        row: {SyncColumns.id: id, 'name': name},
      );

  group('defaultRealtimeBackoff', () {
    test('grows exponentially and caps at 30s', () {
      expect(defaultRealtimeBackoff(0), const Duration(milliseconds: 200));
      expect(defaultRealtimeBackoff(1), const Duration(milliseconds: 200));
      expect(defaultRealtimeBackoff(2), const Duration(milliseconds: 400));
      expect(defaultRealtimeBackoff(3), const Duration(milliseconds: 800));
      expect(defaultRealtimeBackoff(9), const Duration(seconds: 30));
      expect(defaultRealtimeBackoff(50), const Duration(seconds: 30));
    });
  });

  test('applies upsert events to the local store', () async {
    final db = InMemoryAdapter();
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      localDb: db,
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.add(upsert('1', 'live'));
    await pump();
    await controllers.last.close();
    await running;

    expect((await db.getById('things', '1'))?['name'], 'live');
    expect(channel.status, RealtimeStatus.disconnected);
  });

  group('monotonic apply (no-regression)', () {
    RealtimeEvent versioned(String id, String name, int updatedAt) =>
        RealtimeEvent(
          table: 'things',
          type: RealtimeEventType.upsert,
          row: {
            SyncColumns.id: id,
            'name': name,
            SyncColumns.updatedAt: updatedAt,
          },
        );

    Future<InMemoryAdapter> applyAll(
      List<RealtimeEvent> events, {
      bool monotonic = true,
    }) async {
      final db = InMemoryAdapter();
      final controllers = <StreamController<RealtimeEvent>>[];
      final channel = RealtimeChannel(
        connect: () {
          final c = StreamController<RealtimeEvent>();
          controllers.add(c);
          return c.stream;
        },
        localDb: db,
        monotonic: monotonic,
        maxReconnectAttempts: 0,
        sleep: (_) async {},
      );
      final running = channel.start();
      await pump();
      for (final e in events) {
        controllers.last.add(e);
        await pump();
      }
      await controllers.last.close();
      await running;
      return db;
    }

    test('skips an out-of-order older row', () async {
      final db = await applyAll([
        versioned('1', 'newer', 9000),
        versioned('1', 'older', 1000), // arrives late, must be ignored
      ]);
      expect((await db.getById('things', '1'))?['name'], 'newer');
    });

    test('applies a newer row', () async {
      final db = await applyAll([
        versioned('1', 'old', 1000),
        versioned('1', 'new', 5000),
      ]);
      expect((await db.getById('things', '1'))?['name'], 'new');
    });

    test('applies the first event for a brand-new row', () async {
      final db = await applyAll([versioned('1', 'first', 1000)]);
      expect((await db.getById('things', '1'))?['name'], 'first');
    });

    test('applies rows that lack a comparable updated_at', () async {
      final db = await applyAll([
        versioned('1', 'newer', 9000),
        RealtimeEvent(
          table: 'things',
          type: RealtimeEventType.upsert,
          row: {SyncColumns.id: '1', 'name': 'no-version'},
        ),
      ]);
      expect((await db.getById('things', '1'))?['name'], 'no-version');
    });

    test('monotonic:false applies blindly (regresses)', () async {
      final db = await applyAll(
        [versioned('1', 'newer', 9000), versioned('1', 'older', 1000)],
        monotonic: false,
      );
      expect((await db.getById('things', '1'))?['name'], 'older');
    });

    test('onApplied fires after an apply but not after a monotonic skip',
        () async {
      var applied = 0;
      final db = InMemoryAdapter();
      final controllers = <StreamController<RealtimeEvent>>[];
      final channel = RealtimeChannel(
        connect: () {
          final c = StreamController<RealtimeEvent>();
          controllers.add(c);
          return c.stream;
        },
        localDb: db,
        onApplied: () async => applied++,
        maxReconnectAttempts: 0,
        sleep: (_) async {},
      );
      final running = channel.start();
      await pump();
      controllers.last.add(versioned('1', 'newer', 9000)); // applied
      await pump();
      controllers.last.add(versioned('1', 'older', 1000)); // skipped
      await pump();
      await controllers.last.close();
      await running;

      expect(applied, 1); // only the applied event triggered the hook
    });
  });

  test('onEvent overrides the default auto-apply', () async {
    final db = InMemoryAdapter();
    final seen = <RealtimeEvent>[];
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      localDb: db,
      onEvent: (e) async => seen.add(e),
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.add(upsert('1', 'live'));
    await pump();
    await controllers.last.close();
    await running;

    expect(seen, hasLength(1));
    expect(await db.getById('things', '1'), isNull); // not auto-applied
  });

  test('applies a delete tombstone via upsert', () async {
    final db = InMemoryAdapter();
    await db
        .upsert('things', {SyncColumns.id: '1', SyncColumns.deletedAt: null});
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      localDb: db,
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.add(
      RealtimeEvent(
        table: 'things',
        type: RealtimeEventType.delete,
        row: {
          SyncColumns.id: '1',
          SyncColumns.deletedAt: 123,
          SyncColumns.isSynced: 1
        },
      ),
    );
    await pump();
    await controllers.last.close();
    await running;

    expect((await db.getById('things', '1'))?[SyncColumns.deletedAt], 123);
  });

  test('a signal-only event (null row) is routed to onEvent', () async {
    var pulls = 0;
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      onEvent: (e) async {
        if (e.row == null) pulls++;
      },
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.add(
      RealtimeEvent(table: 'things', type: RealtimeEventType.upsert),
    );
    await pump();
    await controllers.last.close();
    await running;

    expect(pulls, 1);
  });

  test('emits connecting -> connected -> disconnected', () async {
    final statuses = <RealtimeStatus>[];
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );
    channel.statusStream.listen(statuses.add);

    final running = channel.start();
    await pump();
    await controllers.last.close();
    await running;

    expect(
      statuses,
      containsAllInOrder([
        RealtimeStatus.connecting,
        RealtimeStatus.connected,
        RealtimeStatus.disconnected,
      ]),
    );
  });

  test('reconnects after the stream closes, until stopped', () async {
    var connects = 0;
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        connects++;
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    await controllers.last.close(); // drop -> reconnect
    await pump();
    await controllers.last.close(); // drop -> reconnect
    await pump();
    await channel.stop();
    await running;

    expect(connects, greaterThanOrEqualTo(3));
    expect(channel.status, RealtimeStatus.disconnected);
  });

  test('reports a stream error and reconnects', () async {
    final errors = <Object>[];
    var connects = 0;
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        connects++;
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      onError: errors.add,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.addError(StateError('socket dropped'));
    await pump();
    await channel.stop();
    await running;

    expect(errors, isNotEmpty);
    expect(connects, greaterThanOrEqualTo(2));
  });

  test('retries when a connect attempt throws', () async {
    var connects = 0;
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        connects++;
        if (connects == 1) throw StateError('cannot connect');
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      onError: (_) {},
      maxReconnectAttempts: 3,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    await channel.stop();
    await running;

    expect(connects, greaterThanOrEqualTo(2));
  });

  test('a handler error is reported but keeps the channel alive', () async {
    final errors = <Object>[];
    final seen = <String>[];
    final controllers = <StreamController<RealtimeEvent>>[];
    final channel = RealtimeChannel(
      connect: () {
        final c = StreamController<RealtimeEvent>();
        controllers.add(c);
        return c.stream;
      },
      onEvent: (e) async {
        if (e.table == 'bad') throw StateError('boom');
        seen.add(e.table);
      },
      onError: errors.add,
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    final running = channel.start();
    await pump();
    controllers.last.add(
      RealtimeEvent(table: 'bad', type: RealtimeEventType.upsert, row: {}),
    );
    await pump();
    controllers.last.add(
      RealtimeEvent(table: 'good', type: RealtimeEventType.upsert, row: {}),
    );
    await pump();
    await controllers.last.close();
    await running;

    expect(errors, isNotEmpty);
    expect(seen, ['good']);
  });

  test('dispose stops the channel and closes the status stream', () async {
    final channel = RealtimeChannel(
      connect: () => StreamController<RealtimeEvent>().stream,
      maxReconnectAttempts: 0,
      sleep: (_) async {},
    );

    unawaited(channel.start());
    await pump();
    await channel.dispose();

    expect(channel.status, RealtimeStatus.disconnected);
    expect(channel.statusStream.isBroadcast, isTrue);
  });
}
