# test-backend

Minimal Node.js + SQLite backend for end-to-end testing of the `flutter_universal_sync` REST adapter.

Implements the spec's recommended REST contract:

- `GET /sync/:table?since=<millisSinceEpoch>` — delta pull
- `POST /sync/:table` — batch push (insert / update / soft-delete)
- `GET /health` — liveness

Backed by a single SQLite file at `data/sync.db`. Tables match the `SyncColumns` contract from the Dart core package.

## Prerequisites

- Node.js 18+ (`node --version`)
- macOS / Linux (Windows works too if you have a C++ toolchain for `better-sqlite3`)

## Install & run

```bash
cd examples/test-backend
npm install        # builds better-sqlite3 native bindings
npm start          # listens on :3000 (or $PORT)
```

The DB file is auto-created at `data/sync.db` on first start.

## Try it

Boot the server and run the in-process smoke test:

```bash
npm run smoke
```

The smoke test simulates two devices syncing through the backend (insert → pull → update → delta pull → stale-write rejection → soft delete → tombstone propagation) and exits non-zero if any step fails.

For manual exploration:

```bash
# seed a few rows
npm run seed

# pull everything
curl -s http://localhost:3000/sync/things | jq

# pull deltas since 1 second ago
curl -s "http://localhost:3000/sync/things?since=$(($(date +%s%3N) - 1000))" | jq

# push a row
curl -s -X POST http://localhost:3000/sync/things \
  -H 'Content-Type: application/json' \
  -d '{
    "changes": [{
      "operation": "insert",
      "payload": {
        "id": "11111111-1111-4111-8111-111111111111",
        "created_at": 1700000000000,
        "updated_at": 1700000000000,
        "deleted_at": null,
        "is_synced": 0,
        "sync_status": "pending",
        "name": "Hello"
      }
    }]
  }' | jq
```

## Reset state

```bash
npm run reset      # deletes data/sync.db
```

## API contract

### `GET /sync/:table[?since=<ms>]`

Returns rows whose `updated_at` OR `deleted_at` is strictly greater than `since`. Without `since`, returns every row.

```json
{
  "rows": [
    { "id": "...", "created_at": ..., "updated_at": ..., "deleted_at": null, "is_synced": 1, "sync_status": "synced", "name": "Apple" }
  ],
  "server_time": 1735000000000
}
```

### `POST /sync/:table`

```json
{
  "changes": [
    {
      "operation": "insert" | "update" | "delete",
      "payload": { "id": "...", "created_at": ..., "updated_at": ..., "deleted_at": null, "name": "Apple" }
    }
  ]
}
```

Per-entry response:

| status     | reason                | meaning                                               |
|------------|-----------------------|-------------------------------------------------------|
| `ok`       |                       | applied                                               |
| `rejected` | `stale_updated_at`    | server has a newer `updated_at` (LWW lost)            |
| `error`    | (free-form)           | DB error or malformed entry                           |

Conflict resolution server-side is **last-write-wins by `updated_at`**, matching the Dart `LastWriteWinsResolver`. Soft delete sets `deleted_at`; the row is never hard-removed. This matches `SyncEntity.deletedAt` semantics in the Dart package.

## Adding tables

Edit `src/db.js`'s `TABLES` array. Each entry declares the table name plus any user columns beyond the six `SyncColumns`. Restart the server; `IF NOT EXISTS` migrations create new tables on boot.

```js
const TABLES = [
  { name: 'things', extraColumns: { name: 'TEXT' } },
  { name: 'notes',  extraColumns: { title: 'TEXT NOT NULL', body: 'TEXT' } },
];
```

## Pointing the Flutter app at this backend

When `flutter_universal_sync_rest` (Plan 12) ships, configure it with:

```dart
final remote = RestSyncAdapter(
  baseUrl: Uri.parse('http://localhost:3000'),
);
```

The adapter calls `${baseUrl}/sync/${table}` for both push and pull.

## What this is NOT

- Auth — none. Add a middleware before exposing publicly.
- Multi-tenant — one DB, one tenant. Add a `tenant_id` column + filter if you need it.
- Production-ready — no rate limiting, no migrations framework, no horizontal scaling. It's a developer test harness.
