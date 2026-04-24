# `flutter_universal_sync_core` v1 — Design Spec

**Date:** 2026-04-24
**Status:** Approved (brainstorming phase)
**Package:** `flutter_universal_sync_core`
**Scope:** This is Plan 1 of the `flutter_universal_sync` package family (see §2).

---

## 1. Overview

This spec defines the **core contracts** for a federated family of Flutter packages providing offline-first sync between local databases and remote backends.

`flutter_universal_sync_core` ships *contracts only* — no execution logic. No sync engine, no BLoC helpers, no adapter implementations. Every consuming package (adapter plugins, the sync engine, the presentation-layer plugin) depends on this core for shared types.

### Goals of Plan 1

1. Publish a pure-Dart package named `flutter_universal_sync_core` to pub.dev.
2. Define the `SyncEntity` abstract base class.
3. Define the `SyncQueueEntry` data class and the `SyncOperation` / `SyncStatus` enums.
4. Define the `LocalDatabaseAdapter` and `RemoteSyncAdapter` interfaces.
5. Define the `ConflictResolver` interface + three built-in strategies.
6. Define the `SyncColumns` schema contract.
7. Define the `SyncException` error hierarchy.
8. Ship a swappable `IdGenerator` (UUIDv4 by default).
9. Ship a shared `LocalDatabaseAdapterContract` test suite for downstream adapter plans to consume.

### Out of scope for Plan 1

- Sync engine execution (Plan 2)
- Connectivity monitoring (Plan 2)
- Background sync via WorkManager / isolates (Plan 3)
- Local adapter implementations — sqflite, drift, hive, objectbox (Plans 4–7)
- Remote adapter implementations — firebase, supabase, appwrite, graphql, rest (Plans 8–12)
- Repository base class + BLoC/Cubit helpers (Plan 13)
- DI wiring for get_it / injectable / riverpod / provider (best-practices docs, not a plan)
- Example app + pub.dev publishing of the adapter family (Plan 14)

---

## 2. Package Family Topology

Chosen: **federated packages** (bonus recommendation from the original brief).

```
flutter_universal_sync/                        # monorepo root, git repo
├── docs/superpowers/specs/                    # design specs (this doc)
├── docs/superpowers/plans/                    # implementation plans
└── packages/
    ├── flutter_universal_sync_core/           # Plan 1 — this spec
    ├── flutter_universal_sync_engine/         # Plan 2
    ├── flutter_universal_sync_background/     # Plan 3
    ├── flutter_universal_sync_sqflite/        # Plan 4
    ├── flutter_universal_sync_drift/          # Plan 5
    ├── flutter_universal_sync_hive/           # Plan 6
    ├── flutter_universal_sync_objectbox/      # Plan 7
    ├── flutter_universal_sync_firebase/       # Plan 8
    ├── flutter_universal_sync_supabase/       # Plan 9
    ├── flutter_universal_sync_appwrite/       # Plan 10
    ├── flutter_universal_sync_graphql/        # Plan 11
    ├── flutter_universal_sync_rest/           # Plan 12
    └── flutter_universal_sync_bloc/           # Plan 13
```

Users install only the adapters they need; packages version independently; matches established patterns in the Flutter ecosystem (`drift` / `drift_dev` / `drift_sqflite`; `hive` / `hive_flutter`; etc.).

---

## 3. Plan 1 Package Layout

```
packages/flutter_universal_sync_core/
├── lib/
│   ├── src/
│   │   ├── entities/
│   │   │   ├── sync_entity.dart
│   │   │   ├── sync_queue_entry.dart
│   │   │   ├── sync_operation.dart
│   │   │   └── sync_status.dart
│   │   ├── adapters/
│   │   │   ├── local_database_adapter.dart
│   │   │   └── remote_sync_adapter.dart
│   │   ├── conflict/
│   │   │   ├── conflict_resolver.dart
│   │   │   ├── last_write_wins_resolver.dart
│   │   │   ├── server_priority_resolver.dart
│   │   │   └── client_priority_resolver.dart
│   │   ├── schema/
│   │   │   └── sync_columns.dart
│   │   ├── errors/
│   │   │   └── sync_errors.dart
│   │   ├── id/
│   │   │   └── id_generator.dart
│   │   └── testing/
│   │       └── local_database_adapter_contract.dart
│   ├── flutter_universal_sync_core.dart       # production barrel export
│   └── testing.dart                           # test-only barrel export
├── test/
│   └── (one test file per public type + a stub adapter to validate the contract suite)
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
└── LICENSE                                    # MIT
```

### pubspec

- **name:** `flutter_universal_sync_core`
- **description:** Core contracts for the `flutter_universal_sync` offline-first sync family.
- **version:** `0.1.0` (pre-v1; contracts may evolve during adapter plan integration)
- **environment:** `sdk: ^3.4.0`, no Flutter constraint
- **runtime deps:** `uuid: ^4.4.0`
- **dev deps:** `test: ^1.25.0`, `lints: ^4.0.0`, `coverage: ^1.8.0`
- **homepage / repository / issue_tracker:** `https://github.com/<TBD>/flutter_universal_sync` (set before first publish)

### Pure Dart, not Flutter

Plan 1 has no `flutter` SDK dependency. This:
- Lets tests run on plain `dart test`, no device/emulator.
- Allows server-side Dart users to consume core contracts.
- Downstream adapter packages add `flutter` as needed.

---

## 4. Core Data Types

### 4.1 `SyncOperation` (enum)

```dart
enum SyncOperation { insert, update, delete }
```

### 4.2 `SyncStatus` (enum)

```dart
enum SyncStatus { pending, syncing, synced, failed }
```

### 4.3 `SyncEntity` (abstract base class)

```dart
abstract class SyncEntity {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  bool get isSynced;
  SyncStatus get syncStatus;

  Map<String, dynamic> toMap();
}
```

Contract notes:

- `id` is UUIDv4 (RFC 4122); client-generated at insert time; never changes.
- `createdAt` and `updatedAt` are wall-clock `DateTime` with ms precision, stored and compared in UTC.
- `deletedAt == null` means live; non-null means soft-deleted. Deletion sets `deletedAt = DateTime.now().toUtc()`; the row is never hard-removed locally.
- `isSynced` toggles to `true` after a successful push.
- `syncStatus` reflects the most recent transition; `SyncStatus.failed` means the last push threw.
- `toMap()` must produce a map whose keys include every `SyncColumns` key with correctly-typed values. Subclasses provide `fromMap` via a named constructor or `factory` by convention (verified in each concrete consumer's tests).

### 4.4 `SyncQueueEntry` (data class)

```dart
class SyncQueueEntry {
  final String id;                        // queue row UUID
  final String table;                     // target user table
  final String entityId;                  // id of the row being synced
  final SyncOperation operation;
  final Map<String, dynamic> payload;     // full row snapshot at enqueue time
  final DateTime createdAt;
  final int retryCount;                   // default 0; Plan 2 engine increments on retries
  final String? lastError;                // default null; set via recordSyncFailure
  final bool synced;

  const SyncQueueEntry({
    required this.id,
    required this.table,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.synced = false,
  });

  SyncQueueEntry copyWith({
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    int? retryCount,
    String? lastError,
    bool? synced,
  });

  Map<String, dynamic> toMap();
  factory SyncQueueEntry.fromMap(Map<String, dynamic> m);

  @override bool operator ==(Object other) => /* all fields */;
  @override int get hashCode => /* all fields */;
}
```

Contract notes:

- `retryCount` and `lastError` are *defined* in Plan 1 but are never mutated here — Plan 2 (Sync Engine) will start using them. Defining them now prevents a schema migration later.
- `payload` is the full row snapshot at enqueue time, not a diff.
- `==` and `hashCode` cover every field so tests can assert equality directly.

---

## 5. Adapter Interfaces

### 5.1 `LocalDatabaseAdapter`

```dart
abstract class LocalDatabaseAdapter {
  Future<void> init();
  Future<void> close();

  // Domain table ops
  Future<void> insert(String table, Map<String, dynamic> data);
  Future<void> update(String table, String id, Map<String, dynamic> data);
  Future<void> delete(String table, String id);                          // soft delete
  Future<Map<String, dynamic>?> getById(String table, String id);
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  });

  // Sync queue ops
  Future<void> enqueueSync(SyncQueueEntry entry);
  Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit});
  Future<void> markSynced(String queueEntryId);
  Future<void> recordSyncFailure(String queueEntryId, String error);

  // Atomicity
  Future<T> transaction<T>(Future<T> Function() action);

  // Schema validation
  Future<void> validateSchema(List<String> tables);
}
```

Contract notes:

- `insert`: persists the row. Sets no sync metadata itself — the caller (repository layer, Plan 13) populates `id`, `createdAt`, `updatedAt`, etc. before calling.
- `update`: **patch semantics** — only keys present in `data` are modified; keys absent from `data` are left unchanged. Caller must include `updatedAt` in `data`. Throws `StateError` if the row does not exist.
- `delete`: **soft delete only**. Sets `deleted_at` to `DateTime.now().toUtc()`; never hard-removes. Hard-deleting violates the contract.
- `getAll(..., includeDeleted: false)` (default): returns only rows with `deleted_at IS NULL`.
- `transaction(fn)`: **must be a real atomic transaction**. Domain write + `enqueueSync` either both succeed or both fail. Hive and ObjectBox adapter plans are responsible for using their native transaction primitives.
- `validateSchema(tables)`: iterates each table, confirms every key in `SyncColumns.required` exists as a column. Throws `SchemaValidationException` listing the missing columns. Called once at app startup by the Sync Engine.

### 5.2 `RemoteSyncAdapter`

```dart
abstract class RemoteSyncAdapter {
  Future<void> pushChange(SyncQueueEntry entry);
  Future<List<Map<String, dynamic>>> pullChanges(String table, DateTime? since);
}
```

Contract notes:

- `pushChange`: pushes a single queue entry (per-op queue — Q6). Throws `SyncPushException` on failure. The engine (Plan 2) decides whether to continue or stop.
- `pullChanges(table, since)`: returns rows updated after `since`. Passing `null` returns all rows. Implementations should request rows where `updated_at > since OR deleted_at > since` so soft-deletes propagate. Pagination is adapter-internal.

---

## 6. Conflict Resolution

### 6.1 `ConflictResolver` (interface)

```dart
abstract class ConflictResolver {
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  );
}
```

The resolver contract is pure: given two row maps, return one merged map. Plan 1 does **not** define *when* a resolver is invoked — that is the Sync Engine's responsibility (Plan 2). The core exposes only the interface and the three built-in strategies.

### 6.2 Built-in resolvers

- **`LastWriteWinsResolver`** — compares `local['updated_at']` vs `remote['updated_at']` (accepts `DateTime` or ISO-8601 strings; resolver normalizes). Later wall-clock time wins. On exact tie, remote wins (deterministic).
- **`ServerPriorityResolver`** — always returns `remote`. Local changes discarded.
- **`ClientPriorityResolver`** — always returns `local`. Remote changes discarded.

Users extend `ConflictResolver` for custom merge logic.

---

## 7. Schema Contract

### `SyncColumns`

```dart
class SyncColumns {
  static const id = 'id';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
  static const isSynced = 'is_synced';
  static const syncStatus = 'sync_status';

  static const required = <String>[
    id,
    createdAt,
    updatedAt,
    deletedAt,
    isSynced,
    syncStatus,
  ];

  static const Map<String, String> types = {
    id: 'TEXT NOT NULL PRIMARY KEY',
    createdAt: 'INTEGER NOT NULL',          // millisSinceEpoch, UTC
    updatedAt: 'INTEGER NOT NULL',
    deletedAt: 'INTEGER',                   // nullable
    isSynced: 'INTEGER NOT NULL DEFAULT 0',
    syncStatus: "TEXT NOT NULL DEFAULT 'pending'",
  };
}
```

Users include these columns in their local table definitions. Adapters validate at init via `validateSchema`. `types` is non-prescriptive — adapters for NoSQL stores (Hive, ObjectBox) translate to native shapes.

---

## 8. Error Types

```dart
sealed class SyncException implements Exception {
  String get message;
}

class SchemaValidationException extends SyncException {
  final String table;
  final List<String> missingColumns;
  // message: "Table $table is missing sync columns: ${missingColumns.join(', ')}"
}

class SyncPushException extends SyncException {
  final String queueEntryId;
  final Object cause;
}

class SyncPullException extends SyncException {
  final String table;
  final Object cause;
}

class ConflictResolutionException extends SyncException {
  final String entityId;
  final Object cause;          // wraps whatever the user's resolver threw
}
```

---

## 9. ID Generation

```dart
abstract class IdGenerator {
  String nextId();
}

class UuidV4Generator implements IdGenerator {
  UuidV4Generator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;

  @override
  String nextId() => _uuid.v4();
}
```

Swappable for tests (e.g. a `SequentialIdGenerator` stub for deterministic assertions). Default is UUIDv4 per Q2.

---

## 10. Shared Contract Test Suite

Each downstream local-adapter plan (4–7) will implement `LocalDatabaseAdapter`. To prevent drift, Plan 1 ships a reusable contract test:

```dart
// lib/src/testing/local_database_adapter_contract.dart
void runLocalDatabaseAdapterContract({
  required LocalDatabaseAdapter Function() factory,
  required String adapterName,
  required Future<void> Function(LocalDatabaseAdapter) createTestTable,
}) {
  group('$adapterName — LocalDatabaseAdapter contract', () {
    // ~25 tests covering:
    //   - insert / update / soft-delete / getById / getAll
    //   - getAll includeDeleted flag behavior
    //   - enqueueSync / pendingSyncEntries / markSynced / recordSyncFailure
    //   - transaction rollback on thrown exception (atomicity)
    //   - validateSchema happy-path and missing-column throws
  });
}
```

Each adapter plan's test file calls this with its factory; uniform behavior is enforced by one set of tests. Plan 1 validates the suite itself by running it against a small in-memory stub adapter living in `test/` (≤ 200 lines; purely to prove the contract suite works, not published).

---

## 11. Testing Strategy

- Pure-Dart test runner (`dart test`); no device/emulator.
- Unit tests per public type: enum serialization, `toMap` / `fromMap` round-trips for `SyncQueueEntry`, `copyWith` correctness, resolver strategies (including tie-breaking and clock-skew edge cases), exception message formatting, `IdGenerator` swappability.
- No integration tests in Plan 1 — integration-style tests live in adapter plans and consume the contract suite.
- Coverage target: ≥ 95%. Tractable because the package is pure types.
- CI: `.github/workflows/core.yml` runs `dart analyze` (no warnings), `dart test --coverage`, and verifies coverage threshold.

---

## 12. Known v1 Limitations

Explicit trade-offs approved during brainstorming; documented here so downstream plans don't re-hash them.

| # | Limitation | Accepted because |
|---|------------|------------------|
| L1 | Wall-clock conflicts are skew-sensitive | Simplicity; LWW chosen over HLC (Q3) |
| L2 | Local DB grows unbounded — no GC of soft-deleted rows | Deferred; easy to add later without breaking contract |
| L3 | Schema typos are runtime, not compile-time | User owns schema (Q5); `validateSchema` catches at init |
| L4 | No multi-row atomicity across the sync boundary | Per-op queue (Q6); transaction API is a future enhancement |
| L5 | **One failing push wedges the queue** | Stop-on-first-failure (Q7); dead-lettering is a future Sync Engine concern |
| L6 | `ConflictResolver` has no context (table/op/metadata) and no abort signal | Minimal contract (Q9); richer contract can be added backward-compatibly later |
| L7 | No aggregate-root FK ordering guarantees | Consequence of L4 |
| L8 | Backend PKs must accept client-supplied UUIDs | `SERIAL` PKs are unsupported (Q2) |

Each surfaces in the README's "Known limitations" section with a pointer to the plan expected to address it (or a statement that it won't be addressed).

---

## 13. Public API Surface

```dart
// lib/flutter_universal_sync_core.dart — production barrel
export 'src/entities/sync_entity.dart';
export 'src/entities/sync_queue_entry.dart';
export 'src/entities/sync_operation.dart';
export 'src/entities/sync_status.dart';
export 'src/adapters/local_database_adapter.dart';
export 'src/adapters/remote_sync_adapter.dart';
export 'src/conflict/conflict_resolver.dart';
export 'src/conflict/last_write_wins_resolver.dart';
export 'src/conflict/server_priority_resolver.dart';
export 'src/conflict/client_priority_resolver.dart';
export 'src/schema/sync_columns.dart';
export 'src/errors/sync_errors.dart';
export 'src/id/id_generator.dart';

// lib/testing.dart — test-only barrel; kept separate so `test` isn't a prod dep
export 'src/testing/local_database_adapter_contract.dart';
```

---

## 14. Success Criteria for Plan 1

Plan 1 is complete when all of the following are true:

1. Monorepo initialized at `/Users/himanshusharma/Documents/flutter_universal_sync/` with git.
2. `packages/flutter_universal_sync_core/` exists, is a valid Dart package, passes `dart analyze` with zero warnings.
3. Every public type in §§4–9 is implemented and exported via the barrel in §13.
4. Every public type has unit tests; line coverage ≥ 95%.
5. `LocalDatabaseAdapterContract` test suite exists and is runnable; verified by one in-memory stub adapter living in `test/`.
6. CI workflow exists and is green on first push.
7. `README.md` documents install, public types, known limitations (L1–L8), and the family topology.
8. `CHANGELOG.md` has a `0.1.0` entry.
9. Package passes `dart pub publish --dry-run` (publishing itself is gated behind adapter integration; not part of Plan 1 success).

---

## 15. Cross-References

- **Original brief:** user-supplied master prompt for `flutter_universal_sync` (offline-first, multi-adapter, pub.dev ready).
- **Brainstorming decisions:** 9 design questions + 1 topology question, all user-approved.
- **Immediate next plan:** Plan 2 — Sync Engine (queue draining, connectivity gate, conflict resolver invocation, partial-push handling).
