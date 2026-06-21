# flutter_universal_sync_engine

Sync engine for the [`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync) family. Drains the queue, pulls deltas, runs conflict resolvers — pure Dart, no Flutter dependency.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_engine: ^0.1.0
```

## Wire it up

The engine is pure Dart. You supply the network-availability monitor. The 30-line snippet below uses `connectivity_plus` and is the recommended starting point.

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
      }
    });
    unawaited(_seed());
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = false;

  Future<void> _seed() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
  }

  @override bool get isOnline => _isOnline;
  @override Stream<bool> get onChange => _controller.stream;

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
```

Then construct the engine:

```dart
final engine = SyncEngine(
  localDb: mySqfliteAdapter,
  remote: myRestAdapter,
  connectivity: ConnectivityPlusMonitor(),
  tables: const {
    'users': TableConfig(conflictResolver: LastWriteWinsResolver()),
    'orders': TableConfig(conflictResolver: ServerPriorityResolver()),
  },
);

await engine.start();

// Listen for state in your UI:
engine.state.listen((snap) {
  if (snap.status == EngineStatus.error) {
    debugPrint('sync error: ${snap.lastError}');
  }
});

// Pull-to-refresh:
await engine.syncNow(pull: true);
```

## Public API

| Type | Purpose |
|---|---|
| `SyncEngine` | The engine. `start`, `stop`, `syncNow({pull})`, `state`, `current`, `dispose`. |
| `SyncStateSnapshot` | `{status, pendingCount, lastSyncedAt?, lastError?}` emitted on every transition. |
| `EngineStatus` | `idle | syncing | error`. |
| `TableConfig` | Per-table conflict resolver (extensible). |
| `ConnectivityMonitor` | Abstract interface; you implement. |
| `defaultBackoff` | `min(2^retryCount * 1s, 5min)`. Override via the `backoff` constructor arg. |

## Idempotency

The engine pushes to the remote, then marks the queue entry synced — in two separate writes. If the process is force-killed between the two, the next drain will re-push the entry. Most adapter operations are idempotent (PUT, DELETE, server-side UPSERT), and `insert` collisions either dedupe by `id` or surface as a conflict the resolver handles. Don't write a remote adapter that breaks under repeated identical writes.

## Known v1 limitations

| # | Limitation | Plan |
|---|---|---|
| L1 | Push-side conflicts (HTTP 409) surface as `SyncPushException` and retry; no `SyncConflictException` type. | Future minor release. |
| L2 | No dead-letter / max-retries cap. Permanently broken entries retry forever (capped at 5 min between attempts). | Future minor release. |
| L3 | Cross-entity drain is serial. | Future minor release. |
| L4 | No per-entry event stream. UIs that want animated progress poll the queue. | Future minor release. |
| L5 | `syncNow(pull: true)` pulls every registered table; no per-call subset. | Future minor release. |
| L6 | `syncNow(pull: true)` joining an already-running `pull: false` cycle does NOT upgrade it. | Document; revisit. |
| L7 | Mark-synced is not bundled with the push in one transaction. See "Idempotency" above. | Documented trade-off. |
| L8 | Engine runs on the main isolate. Large payloads can block the UI thread. | Plan 3 (background sync). |

## Family

- [`flutter_universal_sync_core`](../flutter_universal_sync_core/) — contracts
- [`flutter_universal_sync_engine`](.) — this package
- `flutter_universal_sync_background` (Plan 3, not yet)
- adapter packages — sqflite, drift, firebase, supabase, rest, … (Plans 4–12)

## License

MIT.
