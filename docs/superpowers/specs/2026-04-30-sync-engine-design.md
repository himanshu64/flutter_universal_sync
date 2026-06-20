# `flutter_universal_sync_engine` v1 Design Spec

> **Status:** approved design, ready for implementation plan.
> **Plan slot:** Plan 2 in the family roadmap (see [core spec §2](./2026-04-24-flutter-universal-sync-core-design.md#2-package-family-topology)).
> **Predecessor:** [`flutter_universal_sync_core` v1 design](./2026-04-24-flutter-universal-sync-core-design.md).

---

## 1. Overview

`flutter_universal_sync_engine` is the orchestration package that turns the contracts shipped in `flutter_universal_sync_core` into a working bidirectional sync runtime. It owns three responsibilities:

1. **Queue draining (push):** pull pending `SyncQueueEntry` rows from the local DB, push each to the remote adapter, mark synced, with backoff and per-entity ordering on failure.
2. **Delta pulls:** read remote changes for registered tables since the last cursor, apply to the local DB, invoke the registered `ConflictResolver` when a remote row collides with a local pending edit.
3. **Lifecycle and observability:** drive a hybrid auto-drain loop (connectivity + periodic timer + explicit `syncNow()`), expose a single state-snapshot stream that UIs bind to.

### Goals of Plan 2

- A pure-Dart `SyncEngine` class with the public API described in §3, ready to wire into a Flutter app.
- Co-shipped `flutter_universal_sync_core` 0.2.0 with the contract additions in §4.
- Test suite ≥ 95 % line coverage; CI green on first push; passes `dart pub publish --dry-run`.
- README that documents installation, the wiring snippet for `connectivity_plus`, the public surface, and known v1 limitations.

### Out of scope for Plan 2

- Background sync via WorkManager / BGTaskScheduler / isolates → Plan 3.
- Local adapter implementations (sqflite, drift, hive, objectbox) → Plans 4–7.
- Remote adapter implementations (firebase, supabase, appwrite, graphql, rest) → Plans 8–12.
- A `Stream<SyncEvent>` of per-entry events. Snapshot stream only in v1.
- Push-side conflict resolution (HTTP 409 → resolver). Pull-side only in v1; see §7.
- Parallel cross-entity drain. v1 is serial across groups; revisit when a workload demands it.
- Dead-letter / max-retries cap. v1 retries with exponential backoff infinitely; see §11.
- DI wiring helpers (get_it / riverpod / provider).
- Per-call `tables: [...]` parameter on `syncNow(pull: true)`. v1 pulls all registered tables.
- `pause()` / `resume()` distinct from `start()` / `stop()`.

---

## 2. Package Position in the Family

```
packages/
├── flutter_universal_sync_core/      ← Plan 1 (shipped 0.1.0; bumps to 0.2.0 in this plan)
├── flutter_universal_sync_engine/    ← Plan 2 (this spec)
├── flutter_universal_sync_background/← Plan 3 (will wrap engine in WorkManager / BGTaskScheduler)
├── flutter_universal_sync_<adapter>/ ← Plans 4–12 (implement core's contracts)
└── flutter_universal_sync_bloc/      ← Plan 13
```

Pure-Dart, no Flutter dependency. The engine never imports `connectivity_plus`, `shared_preferences`, `flutter`, or any plugin-bridged package. All Flutter-bound concerns (the connectivity monitor, the WorkManager runner) live downstream.

---

## 3. Public API Surface

### 3.1 `ConnectivityMonitor` (abstract)

```dart
abstract class ConnectivityMonitor {
  bool get isOnline;
  Stream<bool> get onChange;
}
```

Consumers supply the implementation. The engine's contract is minimal on purpose: a synchronous current-state getter and a broadcast stream of transitions. Reference `ConnectivityPlusMonitor` lives in the engine README and the example app — see §8.

### 3.2 `TableConfig`

```dart
class TableConfig {
  const TableConfig({this.conflictResolver = const LastWriteWinsResolver()});
  final ConflictResolver conflictResolver;
}
```

Per-table policy bag. v1 holds only `conflictResolver`. The class exists (rather than passing a bare `ConflictResolver`) so future per-table options (e.g., `pullPriority`, `softDeleteHandling`) are additive rather than breaking.

### 3.3 `EngineStatus`

```dart
enum EngineStatus { idle, syncing, error }
```

Coarse status for the snapshot. `error` indicates the most recent cycle finished with at least one push or pull error; the engine remains operational and will retry on the next trigger.

### 3.4 `SyncStateSnapshot`

```dart
class SyncStateSnapshot {
  const SyncStateSnapshot({
    required this.status,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });
  final EngineStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastError;
}
```

Full state object emitted on every transition. `pendingCount` is `COUNT(*)` of the queue at emission time (`synced=0`, ignoring `next_retry_at`). `lastSyncedAt` is updated only on cycles that complete without error. `lastError` is the most recent error's `toString()`; cleared on the next clean cycle.

### 3.5 `SyncEngine`

```dart
class SyncEngine {
  SyncEngine({
    required LocalDatabaseAdapter localDb,
    required RemoteSyncAdapter remote,
    required ConnectivityMonitor connectivity,
    required Map<String, TableConfig> tables,
    Duration drainInterval = const Duration(minutes: 5),
    Duration Function(int retryCount) backoff = defaultBackoff,
    IdGenerator? idGenerator, // defaults to UuidV4Generator(); not const-constructible
  });

  Stream<SyncStateSnapshot> get state;
  SyncStateSnapshot get current;

  Future<void> start();
  Future<void> stop();
  Future<void> syncNow({bool pull = false});
  Future<void> dispose();
}

/// Default backoff: min(2^retryCount * 1s, 5 min). retryCount 0 → 1 s.
Duration defaultBackoff(int retryCount);
```

**Key behaviors:**

- `state` has BehaviorSubject semantics — late subscribers immediately receive the current snapshot.
- `start()` and `stop()` are idempotent. Double-`start()` does not double-listen on connectivity or schedule a second timer. `stop()` awaits any in-flight cycle to drain naturally; it does not cancel mid-cycle work.
- `syncNow()` coalesces concurrent calls: if a cycle is in flight, the second caller awaits the same `Future`. Critical for "user mashes pull-to-refresh" + "auto-tick collides with explicit call".
- `dispose()` stops the loop, closes the snapshot stream, and renders the engine unusable.

A package-private constructor variant takes an additional `Clock` for tests; the public API does not expose it.

### 3.6 Backoff function

Default: `Duration(milliseconds: math.min(math.pow(2, retryCount).toInt() * 1000, 5 * 60 * 1000))`. `retryCount` of 0 (the first failure's followup retry decision) returns 1 s; retryCount 4 returns 16 s; retryCount 8 returns ~4 min; retryCount ≥ 9 saturates at 5 min. Consumers may override with any pure function `int → Duration`.

---

## 4. Dependent `flutter_universal_sync_core` 0.2.0 Changes

The engine cannot ship against core 0.1.0. Core jumps to 0.2.0 in the same plan, before engine work begins. All additions are non-breaking for v1 consumers (no published 0.1.0 adapters exist) and additive for the contract.

### 4.1 Schema additions (`SyncColumns`)

| Addition | Type | Where | Reason |
|---|---|---|---|
| `nextRetryAt` | `INTEGER` (epoch ms, nullable) | sync queue table | Engine skips entries whose `next_retry_at > now`. Backoff. |
| `_sync_meta` table | `(key TEXT PRIMARY KEY, value TEXT NOT NULL)` | new top-level table | Engine state KV (per-table pull cursors today; future: device id, schema version). |

`SyncColumns` adds the `nextRetryAt` column constant and a new `SyncMetaColumns` constant set (`tableName`, `key`, `value`).

### 4.2 `LocalDatabaseAdapter` interface additions and amendments

**New methods:**

```dart
// Generic engine-state KV. Reads and writes are atomic with respect to
// transaction; setMeta within a transaction is rolled back on failure.
Future<String?> getMeta(String key);
Future<void> setMeta(String key, String value);
Future<void> deleteMeta(String key);

// Pull-pipeline write: insert if no row with this id exists, otherwise
// update. Pull pipeline uses this because it doesn't know whether the
// local row pre-existed. Soft-delete column on `data` is respected.
Future<void> upsert(String table, Map<String, dynamic> data);

// Pull-pipeline conflict detection: did the local already queue an edit
// for this entity? Ordered by created_at ASC. Filtered to synced=0.
Future<List<SyncQueueEntry>> pendingForEntity(String table, String entityId);

// Pull-pipeline conflict resolution: rewrite a queue entry's payload so
// the next push sends the resolver-merged map, not the pre-merge local.
// Other queue fields untouched.
Future<void> rewriteQueuePayload(String entryId, Map<String, dynamic> payload);
```

**Amended methods:**

```dart
// Backoff-aware drain. Existing { int? limit } overload still works
// (readyAt defaults to null = no backoff filtering).
// readyAt: include only entries where next_retry_at IS NULL OR <= readyAt.
Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit, DateTime? readyAt});

// Plan 1 only stored the error string. Plan 2 makes this method the
// single failure-recording call: increments retry_count, stores last_error,
// and sets next_retry_at (engine computes the value from its backoff fn).
// Existing 0.1.0 behavior (error-only) is preserved when nextRetryAt is null
// and incrementRetryCount is false.
Future<void> recordSyncFailure(
  String queueEntryId,
  String error, {
  DateTime? nextRetryAt,
  bool incrementRetryCount = true, // default flips for 0.2.0
});
```

The `recordSyncFailure` amendment is consistent with the Plan 1 docstring's foreshadowing: "Plan 1 does not increment `retry_count`; Plan 2 will."

`pendingSyncEntries`'s signature is backwards-compatible: existing `{int? limit}` calls keep working.

### 4.3 `SyncQueueEntry` additions

```dart
final DateTime? nextRetryAt;
```

`copyWith`, `toMap`, `fromMap`, `==`/`hashCode` updated to round-trip the field.

### 4.4 Contract suite additions

In `lib/src/testing/local_database_adapter_contract.dart`:

- `_sync_meta` KV CRUD round-trips and isolation-with-transaction tests.
- `upsert(table, data)` semantics: insert when absent, update when present, soft-delete column respected, atomic with transaction.
- `pendingSyncEntries(readyAt:)` filtering tests across NULL, past, and future timestamps.
- `pendingForEntity(table, entityId)` ordering and isolation tests.
- `rewriteQueuePayload(entryId, payload)` payload-only mutation test.
- `recordSyncFailure(entryId, error, nextRetryAt:, incrementRetryCount:)` 0.2.0 behavior: retry_count increments, next_retry_at written, last_error stored, no other queue fields touched.
- `SyncQueueEntry` round-trip with `nextRetryAt`.

### 4.5 Versioning and migration

Core jumps `0.1.0 → 0.2.0`. CHANGELOG entry lists each addition and includes a migration snippet for any in-the-wild 0.1.0 adapter (none exist; the discipline matters). Adapters built against 0.1.0 will fail core's `validateSchema` after upgrade until they add the column and table.

### 4.6 Scope discipline

These core additions exist solely to support the engine. We do NOT add `SyncEngine`, `EngineStatus`, `SyncStateSnapshot`, or any engine-specific concept to core. Core stays a contracts package; engine concepts live in the engine package.

---

## 5. Drain Loop Architecture

The auto-drain loop is the engine's heartbeat. Three triggers funnel into one debounced cycle scheduler.

### 5.1 Triggers

```
                          ┌───────────────────┐
   ConnectivityMonitor    │                   │
   onChange (true)  ──────▶                   │
                          │                   │
   Periodic timer  ───────▶   _scheduleCycle  │
   (drainInterval)        │   (debounced)     │
                          │                   │
   syncNow()       ───────▶                   │
                          └─────────┬─────────┘
                                    │
                                    ▼
                          ┌───────────────────┐
                          │  _runCycle()      │
                          │                   │
                          │  1. emit syncing  │
                          │  2. push          │
                          │  3. pull (opt-in) │
                          │  4. emit idle/err │
                          └───────────────────┘
```

- **Connectivity transition to online** fires `_scheduleCycle(pull: false)`. False→true only; we do not drain on true→false.
- **Periodic timer** is `Timer.periodic(drainInterval, ...)`. First tick at `T + drainInterval`; `start()` itself fires one cycle immediately if already online so the user doesn't wait `drainInterval` for first sync. Timer is reset after every cycle completion to avoid redundant ticks immediately following a manual `syncNow()`.
- **`syncNow({bool pull})`** funnels the user's explicit request through the same scheduler. The `pull` flag rides along.

### 5.2 Debounce and coalescing

`_scheduleCycle` holds a single `Future<void>? _inFlight`. New callers `return _inFlight ?? (_inFlight = _runCycle(...))`. When `_runCycle` resolves, `_inFlight` is reset to `null`. This means:

- Two triggers within ~50 ms (e.g., connectivity-online + timer-tick) result in one cycle.
- A `syncNow()` call mid-cycle does not start a second cycle; it awaits the current one and then returns. (This is intentional — it gives users a "wait until in-flight sync is done" semantic for free.)
- If a call requests `pull: true` while a cycle is already running with `pull: false`, the in-flight cycle is NOT upgraded to also pull. The caller is told the truth: the cycle they're awaiting did what it was already doing. v1 trade-off; documented in the README.

### 5.3 Cycle phases (`_runCycle`)

1. **Online guard.** If `connectivity.isOnline` is false, emit `EngineStatus.idle` snapshot and return without push/pull. Connectivity-triggered cycles already passed this check; timer-triggered cycles haven't.
2. **Emit `syncing` snapshot** with current `pendingCount`.
3. **Push phase.** Delegated to `PushPipeline.drain()`. Returns a `_PushResult` (succeeded / skipped-due-to-backoff / failed-with-error counts).
4. **Pull phase** (only if `pull: true`). Iterate registered tables in insertion order. For each, delegate to `PullPipeline.pullTable(table, config)`. Continue across tables on error; the cycle's final snapshot reflects the most recent error.
5. **Emit terminal snapshot.** `idle` if no push or pull errors, `error` with `lastError = mostRecent.toString()` otherwise. Update `lastSyncedAt` from the engine's clock when the cycle completed without error.

### 5.4 Concurrency rules

- One cycle runs at a time. `_inFlight` is the only synchronization primitive.
- During a cycle, new connectivity events / timer ticks / `syncNow()` calls all await `_inFlight`.
- `stop()` cancels the timer and connectivity subscription but does NOT cancel an in-flight cycle. It awaits the cycle to drain naturally. This means `stop()` can take up to one cycle's worth of time. `dispose()` does the same and then nulls everything out.

### 5.5 Error policy

The cycle never throws. Adapter exceptions (`SyncPushException`, `SyncPullException`, `SchemaValidationException`, `ConflictResolutionException`, plus any unexpected `Object`) are caught at the cycle boundary, recorded into the snapshot's `lastError`, and the engine remains operational. Specific exception types are preserved in the queue's `last_error` column (per-entry); the snapshot stores only the most recent `error.toString()`. Power users can subscribe to a separate stream later if they need typed errors — not in v1.

---

## 6. Push Pipeline

`PushPipeline.drain()` makes "per-entity stop, cross-entity continue" concrete.

### 6.1 Algorithm

```
1. entries = await localDb.pendingSyncEntries(readyAt: clock.now())
   // synced=0 AND (next_retry_at IS NULL OR next_retry_at <= now)
   // ordered by created_at ASC

2. groups = groupBy(entries, e => e.entity_id)
   // preserve relative order within each group

3. for each group (parallelism = 1, ordered by group's earliest created_at):
     for each entry in group (in created_at order):
       try:
         await remote.pushChange(entry)
         await localDb.markSynced(entry.id)
       catch error:
         await localDb.recordSyncFailure(
           entry.id,
           error.toString(),
           nextRetryAt: clock.now().add(backoff(entry.retryCount + 1)),
         )
         break  // stop this group; continue to next group
```

### 6.2 Why serial within a group

Causal ordering. `update name`, `update email`, `delete user` for the same entity must apply in that order, and the `delete` must NOT push if `update email` failed.

### 6.3 Why serial across groups in v1

Simplicity. Most apps have <10 pending ops at any moment; serial across groups is fast enough. The contract suite already requires `transaction` to be atomic, so parallel-across-groups is a future enhancement, not a contract change.

### 6.4 Mark-synced and failure-record are NOT wrapped in `transaction`

`markSynced` and `recordSyncFailure` are single-row writes that the adapter implements atomically on its own. Wrapping them in `transaction(...)` adds no atomicity over the adapter's existing per-method guarantees. We do NOT bundle "push to remote + mark synced" in one transaction either, because the push is network I/O and would hold the local DB write lock for hundreds of ms.

**Trade-off:** if the app is force-killed between successful push and mark-synced, we double-push on restart. Accepted because:
- `update` and `delete` operations are idempotent on most remote APIs (PUT, DELETE).
- `insert` collisions either dedupe by `id` (UPSERT) on the server, or surface as a conflict the resolver handles at the next pull.

Documented prominently in the engine README's "Idempotency" section.

### 6.5 `_PushResult` (private)

```dart
class _PushResult {
  final int succeeded;
  final int skippedDueToBackoff;
  final List<({SyncQueueEntry entry, Object error})> failed;
}
```

The cycle aggregates `failed` into the snapshot's `lastError` (most recent failure wins). Per-entry detail is preserved in the queue's `last_error` column.

---

## 7. Pull Pipeline & Conflict Detection

`PullPipeline.pullTable(table, config)` is where the conflict resolver fires.

### 7.1 Algorithm

```
1. cursorStr = await localDb.getMeta('pull_cursor:$table')
   since = cursorStr != null ? DateTime.parse(cursorStr) : null

2. remoteRows = await remote.pullChanges(table, since)

3. for each remoteRow in remoteRows:
     entityId = remoteRow[SyncColumns.id] as String
     await localDb.transaction(() async:
       localRow = await localDb.getById(table, entityId)
       pendingForEntity = await localDb.pendingForEntity(table, entityId)

       if pendingForEntity.isEmpty:
         # no competing local edit. server wins.
         await localDb.upsert(table, remoteRow)
       else:
         # conflict: local has unpushed edit AND server has new version.
         merged = config.conflictResolver.resolve(localRow!, remoteRow)
         await localDb.upsert(table, merged)
         # rewrite the most-recent pending queue entry's payload to merged
         # so the next push sends the resolver's decision, not the pre-merge state.
         await localDb.rewriteQueuePayload(pendingForEntity.last.id, merged)
     )

4. maxUpdatedAt = remoteRows.map((r) => r['updated_at'] as int).fold(0, max)
   if maxUpdatedAt > 0:
     await localDb.setMeta(
       'pull_cursor:$table',
       DateTime.fromMillisecondsSinceEpoch(maxUpdatedAt).toIso8601String(),
     )
```

### 7.2 Conflict invocation rule

The resolver is invoked **only when local has a pending queue entry for that entity**. This is the only situation that represents two competing writers:

- No pending → user hasn't edited this row offline; server data is just new data; upsert blindly. No resolver call.
- Pending exists → user edited offline AND server has new state for the same row. Resolver decides.

This explicitly excludes two cases the design rejected:

- **Server-newer-than-local with no pending edit:** that's propagation, not conflict. Calling a resolver there violates user intuition and burns CPU.
- **Push-side 409:** v1 surfaces as `SyncPushException`, retries with backoff. No `SyncConflictException` type, no push-side resolver invocation. Future opt-in extension.

### 7.3 Why per-row transactions, not per-table

The consistency boundary is the row. A 200-row pull running in one `transaction(...)` would hold the write lock for seconds and block all UI reads. Per-row gets us serialization isolation per entity (which is what conflict detection needs anyway) without freezing the whole DB. The transaction wraps `getById` + `pendingForEntity` + `upsert` (+ optional `rewriteQueuePayload`) so the local read used to decide "is this a conflict?" cannot race with a concurrent `enqueueSync` from the app.

### 7.4 Why we rewrite the queue payload on conflict

If we didn't, the next push would send the user's pre-merge local state and clobber the resolver's decision. Rewriting means the queue keeps the operation type (`update`), but the payload becomes the merged map. The push that follows propagates the resolver's decision to the server.

### 7.5 Cursor advancement is the LAST step

If any per-row apply throws, the cursor is not advanced and we re-pull those rows next cycle. Idempotent because pull-side conflict resolution is deterministic given the same `(local, remote)` inputs.

### 7.6 Edge cases handled

- Empty `remoteRows` → cursor unchanged, no transactions opened, cycle reports success.
- Remote row for an entity that doesn't exist locally → upsert (treated as initial fetch). No conflict path because there's no `localRow` to merge with.
- Remote row with `deleted_at` set → upsert respects the soft-delete column; existing local adapter treats as a tombstone (Plan 1 semantics).
- Pull throws partway through → cursor stays at previous value; idempotent retry next cycle.
- Concurrent `pushChange` writing the same entity_id mid-pull → blocked by `transaction`'s atomicity contract.

---

## 8. `ConnectivityPlusMonitor` Reference Implementation

The engine is pure Dart and does not import `connectivity_plus`. The reference implementation is documented in the engine README and shipped in `examples/sync_demo`:

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

Reasons this is not in the engine package:

1. Adding `connectivity_plus` makes the engine Flutter-only and pulls native plugin glue into transitive deps.
2. `connectivity_plus` has had multiple breaking changes; we'd be locked to its versioning.
3. Some consumers will roll their own (e.g., heartbeat against an internal API endpoint).

The engine README has a first-class "Wire it up" section with this snippet so users don't perceive the wiring as a hidden tax.

---

## 9. Testing Strategy

The engine is high-stakes orchestration logic — every test pins a specific behavior, not "it generally works".

### 9.1 Test doubles

- **`FakeConnectivityMonitor`** — programmable `isOnline` getter and `emit(bool)` for emitting transitions. **As shipped:** lives in `lib/src/testing/` and is re-exported from `package:flutter_universal_sync_engine/testing.dart` so downstream packages can reuse it (see §10).
- **`FakeRemoteSyncAdapter`** — programmable: queue of canned `pushChange` outcomes (success / specific exception), canned `pullChanges` responses keyed by `(table, since)`. Records all calls for assertion. Optional `pushDelay` for concurrency tests. Also under `lib/src/testing/`, re-exported from `testing.dart`.
- **Reuse `InMemoryAdapter`** from `package:flutter_universal_sync_core/testing.dart`. **As shipped:** core 0.2.0 promoted `InMemoryAdapter` out of `test/support/` into `lib/src/testing/` and exports it from `testing.dart` (a published `test/` double cannot be imported across packages). It implements the four new methods (`getMeta`/`setMeta`/`pendingForEntity`/`rewriteQueuePayload`); the contract suite validates atomicity.
- **`FakeClock`** — manually advanceable `DateTime now()` and `Future delay(Duration)`. Stays in the engine's `test/support/` (consumers never import it). Engine takes an optional package-private `Clock` so backoff timing tests don't need real wall time.

### 9.2 Test files

| File | Tests |
|---|---|
| `engine/sync_engine_lifecycle_test.dart` | start/stop idempotency, dispose cleanup, double-start no-op, stop awaits in-flight cycle |
| `engine/sync_engine_drain_test.dart` | snapshot stream emissions (`idle → syncing → idle`), `syncNow()` coalescing, late subscribers see current state |
| `engine/sync_engine_pull_test.dart` | `syncNow(pull: true)` iterates registered tables, error in one table doesn't stop others |
| `engine/sync_engine_offline_test.dart` | `online=false` → `syncNow()` is a no-op snapshot, queue untouched, no remote calls |
| `push/per_entity_grouping_test.dart` | groups by `entity_id`, fail-stop within group, continue across groups, push order matches `created_at` within group |
| `push/backoff_skipping_test.dart` | failed entry's `next_retry_at` is set; subsequent drain skips it; `FakeClock.advance` past `next_retry_at` makes it eligible again |
| `push/idempotency_test.dart` | force-kill simulation: push succeeds but mark-synced doesn't run → next drain re-pushes; documents the trade-off |
| `pull/conflict_detection_test.dart` | no pending → server wins (no resolver call); pending exists → resolver called with `(local, remote)`; merged row written; queue payload rewritten |
| `pull/cursor_advancement_test.dart` | cursor advances to `max(updated_at)` after success; cursor stays put if any per-row apply throws |
| `pull/empty_pull_test.dart` | empty `remoteRows` → cursor unchanged, no transactions opened |
| `meta/cursor_storage_test.dart` | `getMeta`/`setMeta` round-trip via real `InMemoryAdapter` (smoke test; full coverage in core's contract suite) |

### 9.3 Coverage and CI

- Target ≥ 95 % line coverage for the engine package, same bar as core 0.1.0. Enforced by CI.
- `.github/workflows/engine.yml`: same shape as `core.yml` — `dart pub get`, `dart analyze` (zero warnings), `dart test --coverage=coverage`, lcov report uploaded.
- `dart pub publish --dry-run` must pass as a release gate.

### 9.4 Integration testing

`examples/sync_demo` already wires core + sqflite + REST end-to-end. After Plan 2 lands, the demo is migrated to use `SyncEngine` (replacing its ad-hoc drain loop) — the demo serves as the de facto integration test. Not part of the engine package's own test suite; the engine package has no Flutter dep.

---

## 10. Public API Surface (lib/) and Barrels

```
lib/
├── src/
│   ├── connectivity/
│   │   └── connectivity_monitor.dart       # exported
│   ├── engine/
│   │   ├── sync_engine.dart                # exported (drain loop folded in here)
│   │   ├── table_config.dart               # exported
│   │   ├── sync_state_snapshot.dart        # exported
│   │   ├── engine_status.dart              # exported
│   │   ├── backoff.dart                    # exported (defaultBackoff)
│   │   └── _clock.dart                     # private (Clock abstraction)
│   ├── push/
│   │   └── push_pipeline.dart              # private
│   ├── pull/
│   │   └── pull_pipeline.dart              # private
│   ├── meta/
│   │   └── meta_keys.dart                  # private (constants)
│   └── testing/
│       ├── fake_connectivity_monitor.dart  # re-exported via testing.dart
│       └── fake_remote_sync_adapter.dart   # re-exported via testing.dart
├── flutter_universal_sync_engine.dart      # production barrel
└── testing.dart                            # FakeConnectivityMonitor, FakeRemoteSyncAdapter
```

**As shipped:** the drain-loop logic was small enough to live inside
`sync_engine.dart` rather than a separate `_drain_loop.dart`. The test
doubles live under `lib/src/testing/` (not `test/support/`) so the
`testing.dart` barrel can re-export them to downstream packages.

Production barrel re-exports:
- `ConnectivityMonitor`
- `TableConfig`
- `EngineStatus`
- `SyncStateSnapshot`
- `SyncEngine`
- `defaultBackoff`

Testing barrel re-exports test doubles for downstream packages that integration-test against the engine.

---

## 11. Known v1 Limitations

| # | Limitation | Plan to address |
|---|---|---|
| L1 | Push-side conflict (HTTP 409) surfaces as `SyncPushException` with backoff retry; no `SyncConflictException` type; resolver not invoked on push side. | Future minor release; opt-in via richer `RemoteSyncAdapter` exception. |
| L2 | No dead-letter / max-retries cap. A permanently-broken entry retries forever with backoff capped at 5 min. Queue grows. | Plan 2.5 or first user complaint. |
| L3 | Cross-entity drain is serial. | Future minor release if a real workload demands parallel. |
| L4 | No `Stream<SyncEvent>` of per-entry events. UIs that want animated per-row progress must poll the queue. | Future minor release; non-breaking. |
| L5 | `syncNow(pull: true)` cannot select a subset of registered tables. Pulls all. | Future minor release; non-breaking. |
| L6 | If `syncNow(pull: true)` joins an already-running `pull: false` cycle, it does not upgrade the in-flight cycle to also pull. | Document; revisit if it bites. |
| L7 | Mark-synced is not bundled with the remote push in one transaction; force-kill between push and mark-synced double-pushes on restart. Most adapters' operations are idempotent. | Document in README "Idempotency" section. |
| L8 | Engine runs on the main isolate. Large payloads or expensive resolver merges block the UI thread. | Plan 3 (background) addresses for headless context; main-isolate `compute()` offload is future minor. |

Each surfaces in the engine README's "Known limitations" section.

---

## 12. Success Criteria for Plan 2

Plan 2 is complete when all of the following are true:

1. `flutter_universal_sync_core` 0.2.0 is published-ready: schema and interface additions in §4 are implemented, contract suite extended, CHANGELOG entry written, `dart pub publish --dry-run` passes.
2. `packages/flutter_universal_sync_engine/` exists, is a valid Dart package, passes `dart analyze` with zero warnings.
3. Every public type in §3 is implemented and exported via the barrel in §10.
4. Every public type and every private pipeline class has unit tests; line coverage ≥ 95 %.
5. CI workflow exists (`.github/workflows/engine.yml`) and is green on first push.
6. `README.md` documents install, the `connectivity_plus` wiring snippet (§8), the public surface, the Idempotency note (L7), and known v1 limitations (L1–L8).
7. `CHANGELOG.md` has a `0.1.0` entry.
8. `examples/sync_demo` is migrated to use `SyncEngine` and remains green end-to-end against the existing test backend.
9. Engine package passes `dart pub publish --dry-run`.

---

## 13. Cross-References

- **Predecessor:** [`flutter_universal_sync_core` v1 design](./2026-04-24-flutter-universal-sync-core-design.md).
- **Predecessor plan:** [`flutter_universal_sync_core` v1 implementation plan](../plans/2026-04-24-flutter-universal-sync-core-plan.md).
- **Brainstorming decisions for this spec:** 11 design questions, all user-approved before this doc was written:
  1. Lifecycle model → C (hybrid: `start`/`stop` + `syncNow`).
  2. Connectivity integration → A (injected `ConnectivityMonitor` interface, pure-Dart engine).
  3. Push partial-failure semantics → C (per-entity stop, cross-entity continue).
  4. Pull cadence → C (engine handles both; auto-loop is push-only; pull is opt-in via `syncNow(pull: true)`).
  5. Cursor / engine-state storage → A (generic `_sync_meta` KV table).
  6. Conflict resolver invocation → A (pull-side only when local has pending).
  7. Retry backoff → B (exponential, infinite, `next_retry_at` column).
  8. Auto-drain triggers → B (connectivity + 5-min periodic timer; explicit `syncNow()` for faster latency).
  9. Snapshot stream API → C (full `SyncStateSnapshot` on every transition).
  10. Threading → main isolate only; Plan 3 owns background isolation.
  11. Constructor shape → B (named-arg constructor with `tables: Map<String, TableConfig>`).
- **Immediate next plan:** [`flutter_universal_sync_engine` v1 implementation plan] (to be authored next, sibling to this spec under `docs/superpowers/plans/`).
- **Eventual next spec:** Plan 3 — background sync (WorkManager + BGTaskScheduler + isolate-aware engine wiring).
