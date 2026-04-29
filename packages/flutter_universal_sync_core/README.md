# flutter_universal_sync_core

Core contracts for the [`flutter_universal_sync`](../../) offline-first sync package family. Pure Dart — no Flutter SDK dependency.

**Status:** `0.1.0` — contracts may evolve as adapter and engine packages are built. Pin exactly in your `pubspec.yaml` until `1.0.0`.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.1.0
```

You won't usually depend on `_core` directly — depend on an adapter (for example `flutter_universal_sync_sqflite`) which re-exports these types.

## What's here

Pure contracts, no execution. Every downstream adapter and the sync engine depend on these types.

| Type | Role |
|------|------|
| `SyncEntity` | Abstract base class — every synced domain model extends it. Carries `id`, `createdAt`, `updatedAt`, `deletedAt`, `isSynced`, `syncStatus`. |
| `SyncOperation` | `insert` / `update` / `delete` |
| `SyncStatus` | `pending` / `syncing` / `synced` / `failed` |
| `SyncQueueEntry` | One pending local mutation awaiting remote push. |
| `SyncColumns` | Canonical sync column names every synced table must declare. |
| `LocalDatabaseAdapter` | Port implemented by sqflite / drift / hive / objectbox adapter packages. |
| `RemoteSyncAdapter` | Port implemented by firebase / supabase / appwrite / graphql / rest adapter packages. |
| `ConflictResolver` + `LastWriteWinsResolver` / `ServerPriorityResolver` / `ClientPriorityResolver` | Strategies for reconciling concurrent row versions. |
| `SyncException` + `SchemaValidationException` / `SyncPushException` / `SyncPullException` / `ConflictResolutionException` | Exception hierarchy. |
| `IdGenerator` + `UuidV4Generator` | Swappable id factory (UUIDv4 by default). |

## Family topology

```
flutter_universal_sync_core           ← you are here (contracts only)
├── flutter_universal_sync_engine     ← sync engine (drains the queue)
├── flutter_universal_sync_background ← WorkManager / isolates
├── flutter_universal_sync_sqflite    ← LocalDatabaseAdapter: sqflite
├── flutter_universal_sync_drift      ← LocalDatabaseAdapter: drift
├── flutter_universal_sync_hive       ← LocalDatabaseAdapter: hive
├── flutter_universal_sync_objectbox  ← LocalDatabaseAdapter: objectbox
├── flutter_universal_sync_firebase   ← RemoteSyncAdapter: firebase
├── flutter_universal_sync_supabase   ← RemoteSyncAdapter: supabase
├── flutter_universal_sync_appwrite   ← RemoteSyncAdapter: appwrite
├── flutter_universal_sync_graphql    ← RemoteSyncAdapter: graphql
├── flutter_universal_sync_rest       ← RemoteSyncAdapter: rest
└── flutter_universal_sync_bloc       ← BLoC/Cubit helpers, repository base
```

## Known v1 limitations

These trade-offs are deliberate for `0.1.0`. Each will either be addressed in a later package or stay as documented caveats.

1. **Wall-clock conflicts are skew-sensitive.** Last-Write-Wins compares device `updated_at`. A device with a wrong clock "wins" incorrectly.
2. **Local DB grows unbounded.** Soft-deleted rows are never hard-removed locally. Garbage collection is a future enhancement.
3. **Schema typos are runtime, not compile-time.** `LocalDatabaseAdapter.validateSchema` catches them at init.
4. **No multi-row atomicity across the sync boundary.** Queue is per-op; aggregate roots (order + line items) can partially sync.
5. **One failing push wedges the queue.** Stop-on-first-failure — one bad op blocks every op behind it until resolved. Dead-lettering is a future sync-engine concern.
6. **`ConflictResolver` has no context.** Resolver sees two row maps; no table/operation metadata and no abort signal.
7. **No aggregate-root FK ordering guarantees.** Consequence of (4).
8. **Backends must accept client-supplied UUID PKs.** `SERIAL` PKs are unsupported.

## Implementing `LocalDatabaseAdapter`

Use the shared contract test suite:

```dart
// test/my_adapter_test.dart
import 'package:flutter_universal_sync_core/testing.dart';

void main() {
  runLocalDatabaseAdapterContract(
    factory: MyAdapter.new,
    adapterName: 'MyAdapter',
    createTestTable: (a) async { /* create a `things` table with the sync columns + `name` */ },
    createBrokenTable: (a) async { /* create a `broken` table missing 4 sync columns */ },
  );
}
```

Passing the suite means your adapter conforms to the contract.

## License

MIT — see [LICENSE](LICENSE).
