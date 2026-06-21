# sync_demo

Material UI demo that exercises [`flutter_universal_sync_core`](../../packages/flutter_universal_sync_core/) end-to-end against the [test backend](../test-backend/).

What you can watch live:
- Local-first writes (insert / rename / delete) commit instantly to a local SQLite DB.
- Each mutation enqueues a `SyncQueueEntry` in the same DB transaction (correct-by-construction atomicity).
- The sync runner pushes pending entries one-at-a-time, marks them synced, then pulls deltas from the server.
- Per-row sync-status icons: `cloud_upload` (pending), `cloud_done` (synced), `cloud_off` (failed).
- Pull-to-refresh triggers another sync cycle.

## What's NOT here

This is **demo** code — it ships only what's needed to make a Flutter UI sync visibly. It does not replace the future production packages:

- [`adapters/sqflite_adapter.dart`](lib/adapters/sqflite_adapter.dart) is a single-file `LocalDatabaseAdapter` impl. The production `flutter_universal_sync_sqflite` (Plan 4) will replace it.
- [`adapters/rest_adapter.dart`](lib/adapters/rest_adapter.dart) is a single-file `RemoteSyncAdapter` impl. The production `flutter_universal_sync_rest` (Plan 12) will replace it.
- [`sync_runner.dart`](lib/sync_runner.dart) is a 50-line manual sync driver. The production `flutter_universal_sync_engine` (Plan 2) will add connectivity gating, retry/backoff, dead-lettering, and conflict resolution.

## Run it

### 1. Start the test backend

```bash
cd ../test-backend
npm install
PORT=4567 npm start          # default port 3000 may be taken
```

You should see `flutter_universal_sync test backend listening on http://localhost:4567`.

### 2. Run the Flutter app

From `examples/sync_demo/`:

```bash
flutter pub get

# macOS desktop (easiest — no simulator needed)
flutter run -d macos

# iOS Simulator
flutter run -d <iphone-simulator-id>

# Android emulator (note: localhost ≠ host machine)
flutter run -d <android-emulator-id> \
  --dart-define=SYNC_DEMO_BACKEND=http://10.0.2.2:4567

# Any device with a custom backend URL
flutter run --dart-define=SYNC_DEMO_BACKEND=http://192.168.1.10:4567
```

Default backend URL is `http://localhost:4567`. Override at compile time via `--dart-define=SYNC_DEMO_BACKEND=...`.

### 3. Try the round-trip

1. Tap **+** to add a thing — it appears with an orange `cloud_upload` icon (pending), then flips to green `cloud_done` (synced) once the round-trip completes.
2. In another terminal, push a row directly to the backend:
   ```bash
   curl -s -X POST http://localhost:4567/sync/things \
     -H 'Content-Type: application/json' \
     -d '{"changes":[{"operation":"insert","payload":{"id":"22222222-2222-4222-8222-222222222222","created_at":1700000000000,"updated_at":1700000000000,"deleted_at":null,"name":"From curl"}}]}' | jq
   ```
3. Pull-to-refresh in the app — the new row appears.
4. Swipe a row in the app to soft-delete — both the app and the server agree the row is tombstoned (still queryable with `?since=0`, but absent from the default `getAll`).

## Architecture (matches the package family)

```
┌──────────────────┐   ┌────────────────────────────────────────┐
│  Material UI     │ ← │  ThingRepository (lib/repository.dart) │
│  (lib/main.dart) │   └────────────────────────────────────────┘
└─────────┬────────┘                  │
          │                           ▼
          │           ┌──────────────────────────────────────┐
          ├─ refresh ←┤  SqfliteSyncAdapter                  │  LocalDatabaseAdapter impl
          │           │  tables: things, sync_queue, sync_state │
          │           └──────────────────┬───────────────────┘
          │                              │
          │                              ▼
          │           ┌──────────────────────────────────────┐
          └─ sync   ──→  SyncRunner                          │
                      │  drainQueue → pushChange per-op      │
                      │  pull(since) → merge into local DB   │
                      └──────────────────┬───────────────────┘
                                         │
                                         ▼
                       ┌─────────────────────────────────────┐
                       │  RestSyncAdapter                    │  RemoteSyncAdapter impl
                       │  POST /sync/things                  │
                       │  GET  /sync/things?since=<ms>       │
                       └──────────────────┬──────────────────┘
                                          │
                                          ▼
                       ┌─────────────────────────────────────┐
                       │  test-backend (Node + SQLite)       │
                       └─────────────────────────────────────┘
```

## Reset state

App-side: delete the app's documents directory (or uninstall and reinstall). For macOS specifically:

```bash
rm -rf ~/Library/Containers/com.example.syncDemo
```

Backend-side:

```bash
cd ../test-backend && npm run reset
```
