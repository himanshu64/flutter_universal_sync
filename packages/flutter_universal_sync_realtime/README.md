# flutter_universal_sync_realtime

A **real-time server-push channel** for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. The sync engine pulls on an interval or on demand; this adds the other
half — when the server pushes a change over a **WebSocket** (or SSE, or a
Firestore/Supabase listener), apply it locally right away.

It is transport-agnostic: you supply a thunk that returns a
`Stream<RealtimeEvent>`. The channel handles subscription, ordered application,
backpressure, and reconnect-with-backoff. Because the transport is injected,
the whole thing is testable with plain `StreamController`s — no socket.

## Install

```yaml
dependencies:
  flutter_universal_sync_realtime: ^0.1.0
```

## Apply incoming rows to the local store

Point the channel at your `LocalDatabaseAdapter` and it `upsert`s each event's
row as it arrives:

```dart
import 'package:flutter_universal_sync_realtime/flutter_universal_sync_realtime.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = RealtimeChannel(
  localDb: local, // your sqflite / drift / hive adapter
  connect: () {
    final ws = WebSocketChannel.connect(Uri.parse('wss://api.example.com/sync'));
    return ws.stream.map((frame) {
      final json = jsonDecode(frame as String) as Map<String, dynamic>;
      return RealtimeEvent(
        table: json['table'] as String,
        type: json['deleted'] == true
            ? RealtimeEventType.delete
            : RealtimeEventType.upsert,
        row: json['row'] as Map<String, dynamic>,
      );
    });
  },
);

await channel.start();
// later:
await channel.dispose();
```

A `delete` event should carry a tombstone row (with `deleted_at` set and
`is_synced = 1`), so it applies through the same `upsert` path and is not
re-queued for push.

## Or trigger a pull (signal-only)

If your server only signals "something changed", skip `localDb` and let the
channel kick the engine:

```dart
final channel = RealtimeChannel(
  connect: openSignalStream,
  onEvent: (event) => engine.syncNow(), // pull on every server signal
);
```

`onEvent` takes full control of every event when present (it overrides the
auto-apply path).

## Reconnect & status

The transport will drop; the channel reconnects automatically with exponential
backoff (`defaultRealtimeBackoff`: 200ms → 30s, overridable via
`reconnectBackoff`). Cap attempts with `maxReconnectAttempts` (default: forever).
A successful connection resets the counter. Observe connectivity via:

```dart
channel.statusStream.listen((s) => print(s)); // connecting / connected / disconnected
channel.status; // current value
```

Events are applied **in order** with backpressure — the subscription pauses
until each event's handler completes, so a slow write never drops or reorders a
later event. Handler and transport errors are reported to `onError` and never
kill the channel.

## License

MIT — see [LICENSE](LICENSE).
