@Tags(['integration'])
library;

import 'dart:convert';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_realtime/flutter_universal_sync_realtime.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live end-to-end check against the public echo server `wss://echo.websocket.org`.
/// It echoes back every frame we send, which lets us drive a real
/// `RealtimeChannel` over a real WebSocket: send a row event → the server echoes
/// it → the channel decodes and applies it to the local store.
///
/// Run with `dart test -t integration`. Excluded from the default/coverage run.
void main() {
  /// Polls [condition] until true or the [timeout] elapses.
  Future<void> until(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('condition not met within $timeout');
  }

  RealtimeEvent decode(String frame) {
    final json = jsonDecode(frame) as Map<String, dynamic>;
    return RealtimeEvent(
      table: json['table'] as String,
      type: RealtimeEventType.upsert,
      row: (json['row'] as Map).cast<String, dynamic>(),
    );
  }

  test(
    'applies a row echoed back over a real WebSocket',
    () async {
      final ws = WebSocketChannel.connect(
        Uri.parse('wss://echo.websocket.org'),
      );
      await ws.ready;

      final db = InMemoryAdapter();
      final channel = RealtimeChannel(
        localDb: db,
        maxReconnectAttempts: 0,
        // The echo server greets with a non-JSON line first; keep only the
        // JSON frames and decode them into events.
        connect: () => ws.stream
            .where((f) => f is String && f.trimLeft().startsWith('{'))
            .map((f) => decode(f as String)),
      );

      final running = channel.start();
      await until(() async => channel.status == RealtimeStatus.connected);

      // Send a row event; the echo server bounces it straight back to us.
      ws.sink.add(
        jsonEncode({
          'table': 'things',
          'row': {
            SyncColumns.id: '1',
            'name': 'echoed',
            SyncColumns.updatedAt: 1000,
          },
        }),
      );

      await until(() async => (await db.getById('things', '1')) != null);
      expect((await db.getById('things', '1'))?['name'], 'echoed');

      await channel.stop();
      await running;
      await ws.sink.close();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
