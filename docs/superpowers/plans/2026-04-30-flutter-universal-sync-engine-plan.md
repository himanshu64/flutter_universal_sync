# `flutter_universal_sync_engine` v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `flutter_universal_sync_engine` 0.1.0 — the orchestration package that turns the Plan 1 contracts into a working bidirectional sync runtime — together with the dependent `flutter_universal_sync_core` 0.2.0 contract bumps, plus migrate `examples/sync_demo` to consume it.

**Architecture:** Pure-Dart engine package, sibling to `flutter_universal_sync_core`. Hybrid lifecycle (`start`/`stop` + `syncNow`). Connectivity injected via `ConnectivityMonitor` interface. Per-entity push grouping with exponential backoff. Pull-side conflict resolution only when local has a pending edit. Single `Stream<SyncStateSnapshot>` with BehaviorSubject semantics for UI.

**Tech Stack:** Dart SDK ^3.4.0; runtime deps `flutter_universal_sync_core: ^0.2.0`, `meta: ^1.10.0`; dev deps `test: ^1.25.0`, `lints: ^4.0.0`, `coverage: ^1.8.0`.

**Spec reference:** [docs/superpowers/specs/2026-04-30-sync-engine-design.md](../specs/2026-04-30-sync-engine-design.md)

---

## Prerequisites

- Dart SDK 3.4+ installed (`dart --version`)
- Working directory: `/Users/himanshusharma/Documents/flutter_universal_sync`
- Plan 1 (core 0.1.0) is shipped. `git log --oneline` must show `docs(core): finalize 0.1.0 CHANGELOG entry`.
- Spec committed: `git log --oneline` must show `docs(engine): design spec for flutter_universal_sync_engine v1 (Plan 2)`.

If any is missing, stop and resolve before Task 0.

---

## Task Layout (preview)

| # | Task | Outputs |
|---|------|---------|
| 0 | Bump core to 0.2.0-dev + CHANGELOG stub | `pubspec.yaml`, `CHANGELOG.md` |
| 1 | `SyncQueueEntry.nextRetryAt` field | entity + tests |
| 2 | `SyncMetaColumns` constants | schema + tests |
| 3 | `LocalDatabaseAdapter.upsert` | interface + InMemory impl + contract suite test |
| 4 | `LocalDatabaseAdapter` meta KV methods | interface + InMemory impl + contract suite test |
| 5 | Extend `pendingSyncEntries` with `readyAt` | interface + InMemory impl + contract suite test |
| 6 | Extend `recordSyncFailure` with backoff args | interface + InMemory impl + contract suite test |
| 7 | `LocalDatabaseAdapter.pendingForEntity` | interface + InMemory impl + contract suite test |
| 8 | `LocalDatabaseAdapter.rewriteQueuePayload` | interface + InMemory impl + contract suite test |
| 9 | Core 0.2.0 finalize: barrel update, CHANGELOG, dry-run | `flutter_universal_sync_core.dart`, `CHANGELOG.md` |
| 10 | Engine package skeleton | `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, stub `CHANGELOG.md` |
| 11 | `ConnectivityMonitor` interface | abstract class + test |
| 12 | `EngineStatus` enum | enum + test |
| 13 | `SyncStateSnapshot` class | data class + test |
| 14 | `TableConfig` class | config + test |
| 15 | `defaultBackoff` function | function + test |
| 16 | Test support: fakes + clock | `test/support/*.dart` |
| 17 | `PushPipeline` (private) | impl + tests |
| 18 | `PullPipeline` (private) | impl + tests |
| 19 | `SyncEngine` skeleton | constructor + dispose + state stream foundation |
| 20 | `SyncEngine.start` / `stop` + drain loop wiring | lifecycle + tests |
| 21 | `SyncEngine.syncNow` + cycle execution | drain + tests |
| 22 | Engine integration tests | offline + multi-table pull |
| 23 | Engine production barrel + smoke test | `flutter_universal_sync_engine.dart` |
| 24 | Engine testing barrel | `testing.dart` |
| 25 | Engine CI workflow | `.github/workflows/engine.yml` |
| 26 | Engine README | `README.md` |
| 27 | Engine 0.1.0 finalize: CHANGELOG, dry-run | `CHANGELOG.md` |
| 28 | Demo: add engine + connectivity_plus deps | `pubspec.yaml`, `ConnectivityPlusMonitor` |
| 29 | Demo: migrate to `SyncEngine` | `lib/sync/*.dart` |
| 30 | Verify demo end-to-end | (no file output; gate) |

---

## File Structure

```
flutter_universal_sync/
├── docs/superpowers/
│   ├── specs/2026-04-30-sync-engine-design.md             (exists)
│   └── plans/2026-04-30-flutter-universal-sync-engine-plan.md  (this file)
├── packages/
│   ├── flutter_universal_sync_core/                       (existing 0.1.0 → 0.2.0)
│   │   ├── pubspec.yaml                                   Tasks 0, 9
│   │   ├── CHANGELOG.md                                   Tasks 0, 9
│   │   ├── lib/src/
│   │   │   ├── entities/sync_queue_entry.dart             Task 1
│   │   │   ├── schema/sync_columns.dart                   Task 2
│   │   │   ├── adapters/local_database_adapter.dart       Tasks 3-8
│   │   │   └── testing/local_database_adapter_contract.dart  Tasks 3-8
│   │   ├── test/
│   │   │   ├── entities/sync_queue_entry_test.dart        Task 1
│   │   │   ├── schema/sync_columns_test.dart              Task 2
│   │   │   ├── support/in_memory_adapter.dart             Tasks 3-8
│   │   │   └── contract_suite_test.dart                   Tasks 3-8
│   │   └── lib/flutter_universal_sync_core.dart           Task 9
│   └── flutter_universal_sync_engine/                     Task 10 (new)
│       ├── pubspec.yaml                                   Task 10
│       ├── analysis_options.yaml                          Task 10
│       ├── LICENSE                                        Task 10
│       ├── CHANGELOG.md                                   Tasks 10 (stub), 27 (final)
│       ├── README.md                                      Task 26
│       ├── lib/
│       │   ├── src/
│       │   │   ├── connectivity/connectivity_monitor.dart Task 11
│       │   │   ├── engine/
│       │   │   │   ├── engine_status.dart                 Task 12
│       │   │   │   ├── sync_state_snapshot.dart           Task 13
│       │   │   │   ├── table_config.dart                  Task 14
│       │   │   │   ├── backoff.dart                       Task 15
│       │   │   │   └── sync_engine.dart                   Tasks 19, 20, 21
│       │   │   ├── push/push_pipeline.dart                Task 17
│       │   │   ├── pull/pull_pipeline.dart                Task 18
│       │   │   └── meta/meta_keys.dart                    Task 18
│       │   ├── flutter_universal_sync_engine.dart         Task 23
│       │   └── testing.dart                               Task 24
│       └── test/
│           ├── support/
│           │   ├── fake_connectivity_monitor.dart         Task 16
│           │   ├── fake_remote_sync_adapter.dart          Task 16
│           │   └── fake_clock.dart                        Task 16
│           ├── connectivity/connectivity_monitor_test.dart Task 11
│           ├── engine/
│           │   ├── engine_status_test.dart                Task 12
│           │   ├── sync_state_snapshot_test.dart          Task 13
│           │   ├── table_config_test.dart                 Task 14
│           │   ├── backoff_test.dart                      Task 15
│           │   ├── sync_engine_lifecycle_test.dart        Task 20
│           │   ├── sync_engine_drain_test.dart            Task 21
│           │   ├── sync_engine_pull_test.dart             Task 22
│           │   └── sync_engine_offline_test.dart          Task 22
│           ├── push/
│           │   ├── per_entity_grouping_test.dart          Task 17
│           │   ├── backoff_skipping_test.dart             Task 17
│           │   └── idempotency_test.dart                  Task 17
│           ├── pull/
│           │   ├── conflict_detection_test.dart           Task 18
│           │   ├── cursor_advancement_test.dart           Task 18
│           │   └── empty_pull_test.dart                   Task 18
│           ├── meta/cursor_storage_test.dart              Task 18
│           └── barrel_test.dart                           Task 23
├── examples/sync_demo/
│   ├── pubspec.yaml                                       Task 28
│   └── lib/sync/
│       ├── connectivity_plus_monitor.dart                 Task 28
│       └── (demo migration files)                         Task 29
└── .github/workflows/engine.yml                           Task 25
```

---

## Conventions

- **Commits:** Conventional Commits (`feat:`, `test:`, `chore:`, `docs:`, `ci:`, `refactor:`). Co-author trailer optional.
- **Test commands:** from the package directory under test. Use `dart test path/to/file.dart` or `dart test --name "pattern"`.
- **Analyze:** every task ends by running `dart analyze` from the package dir; expect zero issues.
- **Commit cadence:** one commit per task (test + impl combined) unless a task explicitly says otherwise.
- **Path notation:** within a task's `Files:` block, paths are absolute or relative to the monorepo root; commands inside steps are explicit about the directory they expect.
- **Scope (`pkg-core` / `pkg-engine` / `sync_demo`):** commit messages use these scopes consistently with Plan 1.

---

## Task 0: Bump core to 0.2.0-dev + CHANGELOG stub

The whole engine plan ships against core 0.2.0. We jump core's version to a `0.2.0-dev` pre-release immediately so every subsequent commit lands under the new minor, then drop `-dev` in Task 9 once all 0.2.0 work is in.

**Files:**
- Modify: `packages/flutter_universal_sync_core/pubspec.yaml`
- Modify: `packages/flutter_universal_sync_core/CHANGELOG.md`

- [ ] **Step 1: Bump version**

Edit `packages/flutter_universal_sync_core/pubspec.yaml` line 3:

```yaml
version: 0.2.0-dev
```

- [ ] **Step 2: Insert CHANGELOG stub**

At the top of `packages/flutter_universal_sync_core/CHANGELOG.md`, **above** the existing `## 0.1.0 — 2026-04-24` entry, insert:

```markdown
## 0.2.0 — Unreleased

Engine-support contract bumps. See spec
`docs/superpowers/specs/2026-04-30-sync-engine-design.md` §4.

### Added
- (filled in across Tasks 1–8 of the engine plan)

### Changed
- (filled in across Tasks 1–8 of the engine plan)

### Migration
- 0.1.0 adapters need to add the `next_retry_at INTEGER` column to the
  sync queue table and create the `_sync_meta(key TEXT PRIMARY KEY,
  value TEXT NOT NULL)` table. No 0.1.0 adapters are published yet.

```

- [ ] **Step 3: Sanity-check the package still resolves**

```bash
cd packages/flutter_universal_sync_core
dart pub get
dart analyze
dart test
```

Expected: `pub get` succeeds; `analyze` reports zero issues; tests still pass (no test changes yet).

- [ ] **Step 4: Commit**

```bash
git add packages/flutter_universal_sync_core/pubspec.yaml \
        packages/flutter_universal_sync_core/CHANGELOG.md
git commit -m "chore(pkg-core): bump version to 0.2.0-dev for engine support"
```

---

## Task 1: `SyncQueueEntry.nextRetryAt` field

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/entities/sync_queue_entry.dart`
- Modify: `packages/flutter_universal_sync_core/test/entities/sync_queue_entry_test.dart`

- [ ] **Step 1: Write the failing tests**

At the bottom of `packages/flutter_universal_sync_core/test/entities/sync_queue_entry_test.dart`, inside the existing top-level `main()`'s `group('SyncQueueEntry', ...)` (or whatever the existing harness uses — append to the same file), add:

```dart
  group('nextRetryAt', () {
    final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final retryAt = DateTime.utc(2026, 1, 1, 12, 0, 30);

    test('defaults to null', () {
      final entry = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1', 'name': 'Alice'},
        createdAt: t0,
      );
      expect(entry.nextRetryAt, isNull);
    });

    test('round-trips through toMap / fromMap as epoch ms', () {
      final entry = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1'},
        createdAt: t0,
        nextRetryAt: retryAt,
      );
      final map = entry.toMap();
      expect(map['next_retry_at'], retryAt.millisecondsSinceEpoch);
      final restored = SyncQueueEntry.fromMap(map);
      expect(restored.nextRetryAt, retryAt);
    });

    test('toMap encodes null as null (not absent key)', () {
      final entry = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.insert,
        payload: const {'id': 'u1'},
        createdAt: t0,
      );
      final map = entry.toMap();
      expect(map.containsKey('next_retry_at'), isTrue);
      expect(map['next_retry_at'], isNull);
    });

    test('fromMap accepts missing key (back-compat with 0.1.0 maps)', () {
      final map = <String, dynamic>{
        'id': 'q1',
        'table': 'users',
        'entity_id': 'u1',
        'operation': 'update',
        'payload': <String, dynamic>{'id': 'u1'},
        'created_at': t0.millisecondsSinceEpoch,
        'retry_count': 0,
        'last_error': null,
        'synced': 0,
      };
      final entry = SyncQueueEntry.fromMap(map);
      expect(entry.nextRetryAt, isNull);
    });

    test('copyWith replaces nextRetryAt; explicit null clears it', () {
      final base = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1'},
        createdAt: t0,
        nextRetryAt: retryAt,
      );
      final cleared = base.copyWith(nextRetryAt: null);
      expect(cleared.nextRetryAt, isNull);
      final later = DateTime.utc(2026, 1, 1, 12, 5, 0);
      final replaced = base.copyWith(nextRetryAt: later);
      expect(replaced.nextRetryAt, later);
    });

    test('copyWith without nextRetryAt preserves existing value', () {
      final base = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1'},
        createdAt: t0,
        nextRetryAt: retryAt,
      );
      final unchanged = base.copyWith(retryCount: 5);
      expect(unchanged.nextRetryAt, retryAt);
    });

    test('equality and hashCode include nextRetryAt', () {
      final a = SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.update,
        payload: const {'id': 'u1'},
        createdAt: t0,
        nextRetryAt: retryAt,
      );
      final b = a.copyWith(nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 31));
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
      final c = a.copyWith(nextRetryAt: retryAt);
      expect(a == c, isTrue);
      expect(a.hashCode, c.hashCode);
    });
  });
```

- [ ] **Step 2: Run tests, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/entities/sync_queue_entry_test.dart
```

Expected: failures referencing `nextRetryAt` / `next_retry_at`.

- [ ] **Step 3: Update `SyncQueueEntry`**

In `packages/flutter_universal_sync_core/lib/src/entities/sync_queue_entry.dart`:

Add a second sentinel above the class (after the existing `_unset`):

```dart
const Object _unsetRetryAt = Object();
```

In the constructor parameter list (after `this.synced = false,`), add:

```dart
    this.nextRetryAt,
```

Below the existing `final bool synced;` field, add:

```dart
  /// When this entry becomes eligible to retry, or `null` if it is
  /// either fresh (never failed) or eligible immediately. Set by the
  /// sync engine using its backoff function. Filtered against by
  /// [LocalDatabaseAdapter.pendingSyncEntries]'s `readyAt` parameter.
  final DateTime? nextRetryAt;
```

In `copyWith`, add the parameter and a sentinel-based assignment:

```dart
  SyncQueueEntry copyWith({
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    int? retryCount,
    Object? lastError = _unset,
    bool? synced,
    Object? nextRetryAt = _unsetRetryAt,
  }) =>
      SyncQueueEntry(
        id: id,
        table: table,
        entityId: entityId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: identical(lastError, _unset)
            ? this.lastError
            : lastError as String?,
        synced: synced ?? this.synced,
        nextRetryAt: identical(nextRetryAt, _unsetRetryAt)
            ? this.nextRetryAt
            : nextRetryAt as DateTime?,
      );
```

In `toMap`, after `'synced': synced ? 1 : 0,` add:

```dart
        'next_retry_at': nextRetryAt?.toUtc().millisecondsSinceEpoch,
```

In `SyncQueueEntry.fromMap`, after the `synced:` line in the constructor call, add:

```dart
      nextRetryAt: m['next_retry_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              m['next_retry_at'] as int,
              isUtc: true,
            ),
```

In `==`, after `synced == other.synced` add `&& nextRetryAt == other.nextRetryAt`.

In `hashCode`, add `nextRetryAt` as the final argument to `Object.hash(...)`.

- [ ] **Step 4: Run tests, expect PASS**

```bash
cd packages/flutter_universal_sync_core
dart test test/entities/sync_queue_entry_test.dart
```

Expected: all tests in the new `nextRetryAt` group plus all pre-existing tests pass.

- [ ] **Step 5: Run analyze**

```bash
dart analyze
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/entities/sync_queue_entry.dart \
        packages/flutter_universal_sync_core/test/entities/sync_queue_entry_test.dart
git commit -m "feat(pkg-core): add SyncQueueEntry.nextRetryAt for backoff"
```

---

## Task 2: `SyncMetaColumns` constants

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/schema/sync_columns.dart`
- Modify: `packages/flutter_universal_sync_core/test/schema/sync_columns_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `packages/flutter_universal_sync_core/test/schema/sync_columns_test.dart`'s `main()`:

```dart
  group('SyncMetaColumns', () {
    test('exposes table and column names', () {
      expect(SyncMetaColumns.tableName, '_sync_meta');
      expect(SyncMetaColumns.key, 'key');
      expect(SyncMetaColumns.value, 'value');
    });

    test('required lists every column in canonical order', () {
      expect(
        SyncMetaColumns.required,
        const ['key', 'value'],
      );
    });

    test('types map covers every required column', () {
      for (final col in SyncMetaColumns.required) {
        expect(
          SyncMetaColumns.types.containsKey(col),
          isTrue,
          reason: 'types missing entry for $col',
        );
      }
      expect(SyncMetaColumns.types['key'], 'TEXT NOT NULL PRIMARY KEY');
      expect(SyncMetaColumns.types['value'], 'TEXT NOT NULL');
    });

    test('SyncColumns adds nextRetryAt to the queue-table column space', () {
      expect(SyncColumns.nextRetryAt, 'next_retry_at');
      expect(
        SyncColumns.queueTypes[SyncColumns.nextRetryAt],
        'INTEGER',
      );
    });
  });
```

- [ ] **Step 2: Run test, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/schema/sync_columns_test.dart
```

Expected: failures referencing `SyncMetaColumns`, `SyncColumns.nextRetryAt`, `SyncColumns.queueTypes`.

- [ ] **Step 3: Implement**

Append to `packages/flutter_universal_sync_core/lib/src/schema/sync_columns.dart`:

```dart

/// Canonical column names for the engine's generic key/value state table.
///
/// Adapters must create this table at init time. The engine writes
/// per-table pull cursors here today; future engine state (device id,
/// schema version, last-drain timestamp) goes here too.
class SyncMetaColumns {
  SyncMetaColumns._();

  /// The KV table's name. Underscore prefix marks it as engine-owned.
  static const tableName = '_sync_meta';

  /// `TEXT NOT NULL PRIMARY KEY` — engine-defined namespaced key.
  static const key = 'key';

  /// `TEXT NOT NULL` — opaque to adapters; engine encodes as needed.
  static const value = 'value';

  /// Every column the meta table must include, in canonical order.
  static const required = <String>[key, value];

  /// Reference SQL types for SQL-shaped adapters.
  static const Map<String, String> types = {
    key: 'TEXT NOT NULL PRIMARY KEY',
    value: 'TEXT NOT NULL',
  };
}
```

Inside the existing `SyncColumns` class, after the `syncStatus` constant, add:

```dart

  /// Backoff timestamp on the sync queue table, `INTEGER` nullable;
  /// millisSinceEpoch UTC. NULL means "eligible immediately".
  static const nextRetryAt = 'next_retry_at';
```

Then, after the `static const Map<String, String> types = {...};` block, add a second map specifically for queue-table columns:

```dart
  /// Reference SQL types for the engine's sync queue table. Domain
  /// tables use [types]; the queue-internal columns live here so we
  /// don't pollute the per-row schema contract that user tables share.
  static const Map<String, String> queueTypes = {
    nextRetryAt: 'INTEGER',
  };
```

- [ ] **Step 4: Run tests, expect PASS**

```bash
cd packages/flutter_universal_sync_core
dart test test/schema/sync_columns_test.dart
```

Expected: pass.

- [ ] **Step 5: Run analyze**

```bash
dart analyze
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/schema/sync_columns.dart \
        packages/flutter_universal_sync_core/test/schema/sync_columns_test.dart
git commit -m "feat(pkg-core): add SyncMetaColumns and SyncColumns.nextRetryAt"
```

---

## Task 3: `LocalDatabaseAdapter.upsert`

Pull pipeline writes a row that may or may not pre-exist; `insert` throws on conflict, `update` throws when missing. `upsert` removes the branch.

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`
- Modify: `packages/flutter_universal_sync_core/test/contract_suite_test.dart`

- [ ] **Step 1: Write contract suite test**

Append to `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart` (inside the top-level `runLocalDatabaseAdapterContract` function, in the existing CRUD group or in a new group):

```dart
    group('upsert (0.2.0)', () {
      test('inserts when row does not exist', () async {
        final adapter = await openAdapter();
        await adapter.upsert('users', {
          SyncColumns.id: 'u1',
          'name': 'Alice',
          SyncColumns.createdAt: 1000,
          SyncColumns.updatedAt: 1000,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        });
        final row = await adapter.getById('users', 'u1');
        expect(row, isNotNull);
        expect(row![SyncColumns.id], 'u1');
        expect(row['name'], 'Alice');
      });

      test('updates when row exists, replacing payload fields', () async {
        final adapter = await openAdapter();
        await adapter.insert('users', {
          SyncColumns.id: 'u1',
          'name': 'Alice',
          SyncColumns.createdAt: 1000,
          SyncColumns.updatedAt: 1000,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        });
        await adapter.upsert('users', {
          SyncColumns.id: 'u1',
          'name': 'Alicia',
          SyncColumns.createdAt: 1000,
          SyncColumns.updatedAt: 2000,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        });
        final row = await adapter.getById('users', 'u1');
        expect(row!['name'], 'Alicia');
        expect(row[SyncColumns.updatedAt], 2000);
      });

      test('respects deleted_at column on upsert', () async {
        final adapter = await openAdapter();
        await adapter.upsert('users', {
          SyncColumns.id: 'u1',
          'name': 'Alice',
          SyncColumns.createdAt: 1000,
          SyncColumns.updatedAt: 1000,
          SyncColumns.deletedAt: 5000,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        });
        final row = await adapter.getById('users', 'u1');
        expect(row![SyncColumns.deletedAt], 5000);
      });

      test('rolled back when transaction throws', () async {
        final adapter = await openAdapter();
        try {
          await adapter.transaction(() async {
            await adapter.upsert('users', {
              SyncColumns.id: 'u1',
              'name': 'Alice',
              SyncColumns.createdAt: 1000,
              SyncColumns.updatedAt: 1000,
              SyncColumns.deletedAt: null,
              SyncColumns.isSynced: 1,
              SyncColumns.syncStatus: 'synced',
            });
            throw StateError('rollback');
          });
        } on StateError {
          // expected
        }
        expect(await adapter.getById('users', 'u1'), isNull);
      });
    });
```

In `packages/flutter_universal_sync_core/test/contract_suite_test.dart`, the harness should already wire `runLocalDatabaseAdapterContract` against `InMemoryAdapter`. No change needed unless the file shape requires a re-exec.

- [ ] **Step 2: Run contract test, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "upsert"
```

Expected: compilation failure ("method `upsert` not defined") or test failure.

- [ ] **Step 3: Add `upsert` to the abstract interface**

In `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`, after the `delete` method declaration:

```dart

  /// Inserts the row if no row with the same `id` exists, otherwise
  /// patches the existing row with the keys in [data]. Soft-delete
  /// column on [data] is honoured (the engine uses [upsert] to apply
  /// pulled tombstones).
  ///
  /// Caller supplies all sync metadata fields; the adapter does not
  /// populate them. Atomic with respect to [transaction].
  ///
  /// Added in 0.2.0 for the engine's pull pipeline.
  Future<void> upsert(String table, Map<String, dynamic> data);
```

- [ ] **Step 4: Implement in `InMemoryAdapter`**

In `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`, after the existing `update` method:

```dart

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final rows = _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    final id = data[SyncColumns.id] as String;
    if (rows.containsKey(id)) {
      rows[id]!.addAll(data);
    } else {
      rows[id] = Map<String, dynamic>.from(data);
    }
  }
```

- [ ] **Step 5: Run contract test, expect PASS**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "upsert"
```

Expected: pass.

- [ ] **Step 6: Run full test suite + analyze**

```bash
dart test
dart analyze
```

Expected: all tests pass; analyze clean.

- [ ] **Step 7: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): add LocalDatabaseAdapter.upsert"
```

---

## Task 4: `LocalDatabaseAdapter` meta KV methods

`getMeta` / `setMeta` / `deleteMeta`. Engine state KV (per-table pull cursors today; future state tomorrow).

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`

- [ ] **Step 1: Write contract suite tests**

Append a new group to `runLocalDatabaseAdapterContract` in `local_database_adapter_contract.dart`:

```dart
    group('meta KV (0.2.0)', () {
      test('getMeta returns null for missing key', () async {
        final adapter = await openAdapter();
        expect(await adapter.getMeta('does_not_exist'), isNull);
      });

      test('setMeta then getMeta round-trips', () async {
        final adapter = await openAdapter();
        await adapter.setMeta('pull_cursor:users', '2026-01-01T00:00:00.000Z');
        expect(
          await adapter.getMeta('pull_cursor:users'),
          '2026-01-01T00:00:00.000Z',
        );
      });

      test('setMeta overwrites existing value', () async {
        final adapter = await openAdapter();
        await adapter.setMeta('k', 'v1');
        await adapter.setMeta('k', 'v2');
        expect(await adapter.getMeta('k'), 'v2');
      });

      test('deleteMeta removes the key', () async {
        final adapter = await openAdapter();
        await adapter.setMeta('k', 'v');
        await adapter.deleteMeta('k');
        expect(await adapter.getMeta('k'), isNull);
      });

      test('deleteMeta on missing key is a no-op', () async {
        final adapter = await openAdapter();
        await adapter.deleteMeta('missing'); // must not throw
      });

      test('setMeta inside transaction rolls back on throw', () async {
        final adapter = await openAdapter();
        await adapter.setMeta('k', 'before');
        try {
          await adapter.transaction(() async {
            await adapter.setMeta('k', 'after');
            throw StateError('rollback');
          });
        } on StateError {
          // expected
        }
        expect(await adapter.getMeta('k'), 'before');
      });
    });
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "meta KV"
```

Expected: compilation/test failure on missing methods.

- [ ] **Step 3: Add interface methods**

In `local_database_adapter.dart`, after the `upsert` declaration from Task 3:

```dart

  /// Reads the value for [key] from the engine's `_sync_meta` KV table,
  /// or `null` if the key does not exist. Added in 0.2.0.
  Future<String?> getMeta(String key);

  /// Inserts or replaces the value for [key] in `_sync_meta`. Atomic
  /// with respect to [transaction]; rolled back on throw. Added in 0.2.0.
  Future<void> setMeta(String key, String value);

  /// Removes [key] from `_sync_meta`. No-op if the key does not exist.
  /// Atomic with respect to [transaction]. Added in 0.2.0.
  Future<void> deleteMeta(String key);
```

- [ ] **Step 4: Implement in `InMemoryAdapter`**

Add a private field declaration after the `_queue` field:

```dart
  final Map<String, String> _meta = {};
```

Update the `transaction` method's snapshot to include `_meta`. Replace the existing `transaction` body:

```dart
  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    final tablesSnapshot = <String, Map<String, Map<String, dynamic>>>{
      for (final entry in _tables.entries)
        entry.key: {
          for (final row in entry.value.entries)
            row.key: _deepCopyRow(row.value),
        },
    };
    final queueSnapshot = List<SyncQueueEntry>.from(_queue);
    final metaSnapshot = Map<String, String>.from(_meta);
    try {
      return await action();
    } catch (_) {
      _tables
        ..clear()
        ..addAll(tablesSnapshot);
      _queue
        ..clear()
        ..addAll(queueSnapshot);
      _meta
        ..clear()
        ..addAll(metaSnapshot);
      rethrow;
    }
  }
```

After `validateSchema` (or wherever the override-block ends), add:

```dart
  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String value) async {
    _meta[key] = value;
  }

  @override
  Future<void> deleteMeta(String key) async {
    _meta.remove(key);
  }
```

- [ ] **Step 5: Run, expect PASS**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "meta KV"
dart test
dart analyze
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): add getMeta/setMeta/deleteMeta to LocalDatabaseAdapter"
```

---

## Task 5: Extend `pendingSyncEntries` with `readyAt`

Backoff-aware drain. Existing `{int? limit}` form keeps working.

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`

- [ ] **Step 1: Write contract test**

Append a group to `runLocalDatabaseAdapterContract`:

```dart
    group('pendingSyncEntries readyAt (0.2.0)', () {
      Future<void> seed(LocalDatabaseAdapter adapter) async {
        final base = DateTime.utc(2026, 1, 1, 12);
        Future<void> enqueue(String id, DateTime? retryAt) =>
            adapter.enqueueSync(SyncQueueEntry(
              id: id,
              table: 'users',
              entityId: id,
              operation: SyncOperation.insert,
              payload: {'id': id},
              createdAt: base,
              nextRetryAt: retryAt,
            ));
        await enqueue('q-fresh', null); // never failed
        await enqueue('q-past', DateTime.utc(2026, 1, 1, 12, 0, 5)); // due
        await enqueue('q-future', DateTime.utc(2026, 1, 1, 13)); // hold
      }

      test('readyAt = null returns every pending entry (back-compat)', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final all = await adapter.pendingSyncEntries();
        expect(all.map((e) => e.id), ['q-fresh', 'q-past', 'q-future']);
      });

      test('readyAt at T includes NULL and entries with retry_at <= T', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final t = DateTime.utc(2026, 1, 1, 12, 0, 10);
        final ready = await adapter.pendingSyncEntries(readyAt: t);
        expect(ready.map((e) => e.id), ['q-fresh', 'q-past']);
      });

      test('readyAt before all retry_at still returns NULL entries', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final t = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final ready = await adapter.pendingSyncEntries(readyAt: t);
        expect(ready.map((e) => e.id), ['q-fresh']);
      });

      test('readyAt and limit combine', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final t = DateTime.utc(2026, 1, 1, 12, 0, 10);
        final ready = await adapter.pendingSyncEntries(readyAt: t, limit: 1);
        expect(ready, hasLength(1));
        expect(ready.first.id, 'q-fresh');
      });
    });
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "pendingSyncEntries readyAt"
```

Expected: failure on the new `readyAt` parameter not existing.

- [ ] **Step 3: Update interface signature**

In `local_database_adapter.dart`, replace the existing declaration of `pendingSyncEntries`:

```dart
  /// Returns entries with `synced = false` in insertion order, up to [limit].
  ///
  /// If [readyAt] is non-null, also filters entries to those whose
  /// `next_retry_at` is `null` OR `<= readyAt`. The engine passes its
  /// current clock here to skip backoff-deferred entries. When omitted,
  /// every pending entry is returned regardless of `next_retry_at`
  /// (preserves Plan 1 behaviour).
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  });
```

- [ ] **Step 4: Update `InMemoryAdapter` implementation**

Replace its `pendingSyncEntries`:

```dart
  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({
    int? limit,
    DateTime? readyAt,
  }) async {
    bool ready(SyncQueueEntry e) {
      if (readyAt == null) return true;
      final r = e.nextRetryAt;
      return r == null || !r.isAfter(readyAt);
    }
    final pending = _queue.where((e) => !e.synced && ready(e)).toList();
    if (limit == null || limit >= pending.length) return pending;
    return pending.sublist(0, limit);
  }
```

- [ ] **Step 5: Run tests + analyze**

```bash
cd packages/flutter_universal_sync_core
dart test
dart analyze
```

Expected: all tests pass (existing + new); analyze clean.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): pendingSyncEntries supports readyAt for backoff filtering"
```

---

## Task 6: Extend `recordSyncFailure` with backoff args

Plan 1 only stored `last_error`. Plan 2 makes this the single failure-record call: increments `retry_count`, sets `next_retry_at`.

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`

- [ ] **Step 1: Write contract test**

Append:

```dart
    group('recordSyncFailure backoff args (0.2.0)', () {
      Future<SyncQueueEntry> seedOne(LocalDatabaseAdapter adapter) async {
        final entry = SyncQueueEntry(
          id: 'q1',
          table: 'users',
          entityId: 'u1',
          operation: SyncOperation.insert,
          payload: const {'id': 'u1'},
          createdAt: DateTime.utc(2026, 1, 1, 12),
        );
        await adapter.enqueueSync(entry);
        return entry;
      }

      Future<SyncQueueEntry> reload(
        LocalDatabaseAdapter adapter,
        String id,
      ) async {
        final all = await adapter.pendingSyncEntries();
        return all.firstWhere((e) => e.id == id);
      }

      test('default behaviour increments retry_count and sets fields', () async {
        final adapter = await openAdapter();
        await seedOne(adapter);
        final retryAt = DateTime.utc(2026, 1, 1, 12, 0, 5);
        await adapter.recordSyncFailure('q1', 'http 500', nextRetryAt: retryAt);
        final reloaded = await reload(adapter, 'q1');
        expect(reloaded.retryCount, 1);
        expect(reloaded.nextRetryAt, retryAt);
        expect(reloaded.lastError, 'http 500');
      });

      test('repeated failures keep incrementing retry_count', () async {
        final adapter = await openAdapter();
        await seedOne(adapter);
        await adapter.recordSyncFailure('q1', 'e1',
            nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 1));
        await adapter.recordSyncFailure('q1', 'e2',
            nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 4));
        final reloaded = await reload(adapter, 'q1');
        expect(reloaded.retryCount, 2);
        expect(reloaded.lastError, 'e2');
      });

      test('incrementRetryCount=false preserves count (0.1.0 compat)', () async {
        final adapter = await openAdapter();
        await seedOne(adapter);
        await adapter.recordSyncFailure(
          'q1',
          'just-record',
          incrementRetryCount: false,
        );
        final reloaded = await reload(adapter, 'q1');
        expect(reloaded.retryCount, 0);
        expect(reloaded.lastError, 'just-record');
        expect(reloaded.nextRetryAt, isNull);
      });

      test('rolled back inside transaction', () async {
        final adapter = await openAdapter();
        await seedOne(adapter);
        try {
          await adapter.transaction(() async {
            await adapter.recordSyncFailure('q1', 'tx-test',
                nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 10));
            throw StateError('rollback');
          });
        } on StateError {
          // expected
        }
        final reloaded = await reload(adapter, 'q1');
        expect(reloaded.retryCount, 0);
        expect(reloaded.lastError, isNull);
        expect(reloaded.nextRetryAt, isNull);
      });
    });
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "recordSyncFailure backoff"
```

Expected: failure on missing named arguments.

- [ ] **Step 3: Update interface signature**

In `local_database_adapter.dart`, replace the existing `recordSyncFailure` declaration:

```dart
  /// Records a failed push attempt for [queueEntryId].
  ///
  /// 0.2.0 semantics:
  /// - Stores [error] in `last_error`.
  /// - If [incrementRetryCount] (default `true`), increments `retry_count`.
  /// - Writes [nextRetryAt] to the entry's `next_retry_at` column. Pass
  ///   `null` to clear (rare; engine always passes a value when called
  ///   for a real failure).
  ///
  /// Pass `incrementRetryCount: false` and omit [nextRetryAt] to retain
  /// 0.1.0 "just record the error" behaviour. Atomic with [transaction].
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  });
```

- [ ] **Step 4: Implement in `InMemoryAdapter`**

Replace its `recordSyncFailure`:

```dart
  @override
  Future<void> recordSyncFailure(
    String queueEntryId,
    String error, {
    DateTime? nextRetryAt,
    bool incrementRetryCount = true,
  }) async {
    final i = _queue.indexWhere((e) => e.id == queueEntryId);
    if (i < 0) throw StateError('Queue entry $queueEntryId not found');
    final cur = _queue[i];
    _queue[i] = cur.copyWith(
      lastError: error,
      retryCount: incrementRetryCount ? cur.retryCount + 1 : cur.retryCount,
      nextRetryAt: nextRetryAt,
    );
  }
```

- [ ] **Step 5: Run tests + analyze**

```bash
cd packages/flutter_universal_sync_core
dart test
dart analyze
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): recordSyncFailure increments retry_count and sets next_retry_at"
```

---

## Task 7: `LocalDatabaseAdapter.pendingForEntity`

Pull pipeline asks: "is there a pending push for this row?" before deciding whether to invoke the resolver.

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`

- [ ] **Step 1: Write contract test**

Append:

```dart
    group('pendingForEntity (0.2.0)', () {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      Future<void> seed(LocalDatabaseAdapter adapter) async {
        Future<void> enqueue(String qid, String table, String entityId,
            {bool synced = false, int seconds = 0}) =>
            adapter.enqueueSync(SyncQueueEntry(
              id: qid,
              table: table,
              entityId: entityId,
              operation: SyncOperation.update,
              payload: {'id': entityId},
              createdAt: t0.add(Duration(seconds: seconds)),
              synced: synced,
            ));
        await enqueue('q1', 'users', 'u1', seconds: 0);
        await enqueue('q2', 'users', 'u1', seconds: 1);
        await enqueue('q3', 'users', 'u2', seconds: 0);
        await enqueue('q4', 'users', 'u1', synced: true, seconds: 2);
        await enqueue('q5', 'orders', 'u1', seconds: 0);
      }

      test('returns only unsynced entries for the given (table, entity)', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final entries = await adapter.pendingForEntity('users', 'u1');
        expect(entries.map((e) => e.id), ['q1', 'q2']);
      });

      test('returns empty list when no entries exist', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final entries = await adapter.pendingForEntity('users', 'absent');
        expect(entries, isEmpty);
      });

      test('isolates by table', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final entries = await adapter.pendingForEntity('orders', 'u1');
        expect(entries.map((e) => e.id), ['q5']);
      });

      test('orders by created_at ASC', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        final entries = await adapter.pendingForEntity('users', 'u1');
        for (var i = 1; i < entries.length; i++) {
          expect(
            entries[i].createdAt.isBefore(entries[i - 1].createdAt),
            isFalse,
          );
        }
      });
    });
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "pendingForEntity"
```

- [ ] **Step 3: Add interface method**

In `local_database_adapter.dart` after the meta methods:

```dart

  /// Returns unsynced queue entries for the row identified by
  /// (`table`, `entityId`), ordered by `created_at` ASC. Used by the
  /// engine's pull pipeline to detect pending local edits that conflict
  /// with an incoming remote row. Added in 0.2.0.
  Future<List<SyncQueueEntry>> pendingForEntity(String table, String entityId);
```

- [ ] **Step 4: Implement in `InMemoryAdapter`**

```dart
  @override
  Future<List<SyncQueueEntry>> pendingForEntity(
    String table,
    String entityId,
  ) async {
    final filtered = _queue
        .where((e) => !e.synced && e.table == table && e.entityId == entityId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
  }
```

- [ ] **Step 5: Run + analyze**

```bash
cd packages/flutter_universal_sync_core
dart test
dart analyze
```

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): add LocalDatabaseAdapter.pendingForEntity"
```

---

## Task 8: `LocalDatabaseAdapter.rewriteQueuePayload`

Pull pipeline rewrites the most recent pending entry's payload to the resolver-merged map so the next push sends the merged version, not the pre-merge state.

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart`

- [ ] **Step 1: Write contract test**

Append:

```dart
    group('rewriteQueuePayload (0.2.0)', () {
      Future<void> seed(LocalDatabaseAdapter adapter) async {
        await adapter.enqueueSync(SyncQueueEntry(
          id: 'q1',
          table: 'users',
          entityId: 'u1',
          operation: SyncOperation.update,
          payload: const {'id': 'u1', 'name': 'A'},
          createdAt: DateTime.utc(2026, 1, 1, 12),
          retryCount: 2,
          lastError: 'previous-err',
        ));
      }

      Future<SyncQueueEntry> reload(LocalDatabaseAdapter adapter) async {
        final all = await adapter.pendingSyncEntries();
        return all.firstWhere((e) => e.id == 'q1');
      }

      test('replaces payload only', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        await adapter.rewriteQueuePayload('q1', {'id': 'u1', 'name': 'B'});
        final reloaded = await reload(adapter);
        expect(reloaded.payload, {'id': 'u1', 'name': 'B'});
        expect(reloaded.retryCount, 2);
        expect(reloaded.lastError, 'previous-err');
        expect(reloaded.operation, SyncOperation.update);
      });

      test('throws StateError when entryId is unknown', () async {
        final adapter = await openAdapter();
        expect(
          () => adapter.rewriteQueuePayload('absent', const {'id': 'x'}),
          throwsStateError,
        );
      });

      test('rolled back when transaction throws', () async {
        final adapter = await openAdapter();
        await seed(adapter);
        try {
          await adapter.transaction(() async {
            await adapter.rewriteQueuePayload('q1', {'id': 'u1', 'name': 'TX'});
            throw StateError('rollback');
          });
        } on StateError {
          // expected
        }
        final reloaded = await reload(adapter);
        expect(reloaded.payload, {'id': 'u1', 'name': 'A'});
      });
    });
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart --name "rewriteQueuePayload"
```

- [ ] **Step 3: Add interface method**

In `local_database_adapter.dart`:

```dart

  /// Replaces the payload of the queue entry [entryId] with [payload].
  /// Other fields (retry_count, last_error, operation, created_at,
  /// next_retry_at, synced) are untouched. Throws [StateError] if no
  /// such entry exists. Atomic with [transaction]. Added in 0.2.0.
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  );
```

- [ ] **Step 4: Implement in `InMemoryAdapter`**

```dart
  @override
  Future<void> rewriteQueuePayload(
    String entryId,
    Map<String, dynamic> payload,
  ) async {
    final i = _queue.indexWhere((e) => e.id == entryId);
    if (i < 0) throw StateError('Queue entry $entryId not found');
    _queue[i] = _queue[i].copyWith(payload: Map<String, dynamic>.from(payload));
  }
```

- [ ] **Step 5: Run + analyze**

```bash
cd packages/flutter_universal_sync_core
dart test
dart analyze
```

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart \
        packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "feat(pkg-core): add LocalDatabaseAdapter.rewriteQueuePayload"
```

---

## Task 9: Core 0.2.0 finalize — barrel, CHANGELOG, dry-run

**Files:**
- Modify: `packages/flutter_universal_sync_core/pubspec.yaml`
- Modify: `packages/flutter_universal_sync_core/CHANGELOG.md`

- [ ] **Step 1: Confirm barrel re-exports the public additions**

The existing `lib/flutter_universal_sync_core.dart` already exports `schema/sync_columns.dart` (which now also defines `SyncMetaColumns`) and `adapters/local_database_adapter.dart`. Confirm by reading the file:

```bash
cat packages/flutter_universal_sync_core/lib/flutter_universal_sync_core.dart
```

If `SyncMetaColumns` is not visible to consumers, double-check that it is declared in the same `sync_columns.dart` (it should be, per Task 2). No barrel changes required.

- [ ] **Step 2: Drop the `-dev` pre-release suffix**

Edit `pubspec.yaml`:

```yaml
version: 0.2.0
```

- [ ] **Step 3: Replace the CHANGELOG stub with the final entry**

Replace the entire `## 0.2.0 — Unreleased` block at the top of `CHANGELOG.md` with:

```markdown
## 0.2.0 — 2026-04-30

Engine-support contract bumps. Required for `flutter_universal_sync_engine` 0.1.0.
See spec `docs/superpowers/specs/2026-04-30-sync-engine-design.md` §4.

### Added
- `SyncQueueEntry.nextRetryAt` field; round-trips through `toMap`/`fromMap`,
  participates in equality.
- `SyncColumns.nextRetryAt` constant + `SyncColumns.queueTypes` reference SQL.
- `SyncMetaColumns` (table `_sync_meta`, columns `key`, `value`).
- `LocalDatabaseAdapter.upsert(table, data)` — pull-pipeline write.
- `LocalDatabaseAdapter.getMeta(key)` / `setMeta(key, value)` / `deleteMeta(key)`.
- `LocalDatabaseAdapter.pendingForEntity(table, entityId)`.
- `LocalDatabaseAdapter.rewriteQueuePayload(entryId, payload)`.
- `LocalDatabaseAdapter.pendingSyncEntries(...)` gains a `readyAt` parameter
  (back-compat with the existing `{int? limit}` form).
- Contract-suite groups for every addition above; reusable by every adapter.

### Changed
- `LocalDatabaseAdapter.recordSyncFailure(...)` now increments `retry_count`
  and accepts `nextRetryAt`. Pass `incrementRetryCount: false` and omit
  `nextRetryAt` to retain 0.1.0 "just store the error" behaviour.

### Migration (for 0.1.0 adapters; none published yet)
- Add `next_retry_at INTEGER` to your sync queue table.
- Create `_sync_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)`.
- Implement the seven new / amended methods above.
- The shared contract suite exercises every new method — run it.
```

- [ ] **Step 4: Verify `dart pub publish --dry-run`**

```bash
cd packages/flutter_universal_sync_core
dart pub publish --dry-run
```

Expected: passes with `Package has 0 warnings.` (or one warning about the homepage placeholder, same as 0.1.0).

- [ ] **Step 5: Run full test suite + analyze + coverage spot-check**

```bash
dart test
dart analyze
dart test --coverage=coverage
```

Expected: all tests pass; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_core/pubspec.yaml \
        packages/flutter_universal_sync_core/CHANGELOG.md
git commit -m "docs(pkg-core): finalize 0.2.0 CHANGELOG and bump version"
```

---

## Task 10: Engine package skeleton

Create the new package directory + the four manifest files.

**Files (all new):**
- Create: `packages/flutter_universal_sync_engine/pubspec.yaml`
- Create: `packages/flutter_universal_sync_engine/analysis_options.yaml`
- Create: `packages/flutter_universal_sync_engine/LICENSE`
- Create: `packages/flutter_universal_sync_engine/CHANGELOG.md`

- [ ] **Step 1: Create the package directory**

```bash
mkdir -p packages/flutter_universal_sync_engine/lib/src/connectivity
mkdir -p packages/flutter_universal_sync_engine/lib/src/engine
mkdir -p packages/flutter_universal_sync_engine/lib/src/push
mkdir -p packages/flutter_universal_sync_engine/lib/src/pull
mkdir -p packages/flutter_universal_sync_engine/lib/src/meta
mkdir -p packages/flutter_universal_sync_engine/test/support
mkdir -p packages/flutter_universal_sync_engine/test/connectivity
mkdir -p packages/flutter_universal_sync_engine/test/engine
mkdir -p packages/flutter_universal_sync_engine/test/push
mkdir -p packages/flutter_universal_sync_engine/test/pull
mkdir -p packages/flutter_universal_sync_engine/test/meta
```

- [ ] **Step 2: Write `pubspec.yaml`**

```yaml
name: flutter_universal_sync_engine
description: Sync engine for the flutter_universal_sync family. Drains the queue, pulls deltas, runs conflict resolvers — pure Dart, no Flutter dependency.
version: 0.1.0
homepage: https://github.com/REPLACE_ME/flutter_universal_sync
repository: https://github.com/REPLACE_ME/flutter_universal_sync
issue_tracker: https://github.com/REPLACE_ME/flutter_universal_sync/issues

environment:
  sdk: ^3.4.0

dependencies:
  flutter_universal_sync_core: ^0.2.0
  meta: ^1.10.0

dev_dependencies:
  coverage: ^1.8.0
  lints: ^4.0.0
  test: ^1.25.0

dependency_overrides:
  flutter_universal_sync_core:
    path: ../flutter_universal_sync_core
```

The `dependency_overrides` block points at the sibling package during development. It is removed for publishing (Plan 14 covers publishing).

- [ ] **Step 3: Write `analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_in_for_each
    - prefer_final_locals
    - public_member_api_docs
    - require_trailing_commas
    - unawaited_futures
```

- [ ] **Step 4: Write `LICENSE`**

Copy the `LICENSE` file from the core package — same MIT license, same copyright holder.

```bash
cp packages/flutter_universal_sync_core/LICENSE \
   packages/flutter_universal_sync_engine/LICENSE
```

- [ ] **Step 5: Write `CHANGELOG.md` stub**

```markdown
# Changelog

## 0.1.0 — Unreleased

Initial release. Sync engine for the flutter_universal_sync family.

### Added
- (filled in across Tasks 11–22 of the engine plan)
```

- [ ] **Step 6: Resolve deps + analyze**

```bash
cd packages/flutter_universal_sync_engine
dart pub get
dart analyze
```

Expected: `pub get` resolves; `analyze` reports zero issues (the `lib/` tree is empty so the analyzer has nothing to analyze, but the toolchain shouldn't complain).

- [ ] **Step 7: Commit**

```bash
git add packages/flutter_universal_sync_engine/
git commit -m "chore(pkg-engine): scaffold package skeleton"
```

---

## Task 11: `ConnectivityMonitor` interface

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/connectivity/connectivity_monitor.dart`
- Create: `packages/flutter_universal_sync_engine/test/connectivity/connectivity_monitor_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/connectivity/connectivity_monitor_test.dart`:

```dart
import 'package:flutter_universal_sync_engine/src/connectivity/connectivity_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('ConnectivityMonitor is abstract', () {
    expect(
      () => (ConnectivityMonitor as dynamic)(),
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('a concrete implementation satisfies the contract', () async {
    final monitor = _ConcreteMonitor(initial: false);
    expect(monitor.isOnline, isFalse);
    final events = <bool>[];
    final sub = monitor.onChange.listen(events.add);
    monitor.set(true);
    monitor.set(false);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, [true, false]);
    expect(monitor.isOnline, isFalse);
  });
}

class _ConcreteMonitor implements ConnectivityMonitor {
  _ConcreteMonitor({required bool initial}) : _isOnline = initial;
  bool _isOnline;
  final _ctrl = StreamController<bool>.broadcast();
  void set(bool v) {
    _isOnline = v;
    _ctrl.add(v);
  }
  @override
  bool get isOnline => _isOnline;
  @override
  Stream<bool> get onChange => _ctrl.stream;
}
```

Add the missing import at the top:

```dart
import 'dart:async';
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/connectivity/connectivity_monitor_test.dart
```

Expected: compilation failure on missing `ConnectivityMonitor`.

- [ ] **Step 3: Implement**

Create `lib/src/connectivity/connectivity_monitor.dart`:

```dart
/// Reports network availability to the sync engine.
///
/// The engine treats `isOnline == true` as permission to push and pull;
/// it never inspects what kind of network is up. Implementations that
/// care about metered vs. unmetered, or about a heartbeat against a
/// custom endpoint, supply their own logic and surface the result here.
///
/// `onChange` MUST be a broadcast stream — the engine subscribes once
/// per `start()` call. The stream MUST emit only on transitions
/// (false→true and true→false); duplicate consecutive values are
/// permitted but waste cycles.
///
/// `isOnline` MUST reflect the most recent emitted value (or the seed
/// state if nothing has been emitted yet). Concretely: a subscriber
/// that starts listening after `onChange` has emitted `true` will see
/// `isOnline == true` even though it missed the event itself.
abstract class ConnectivityMonitor {
  /// Whether the engine currently has permission to make network calls.
  bool get isOnline;

  /// Broadcast stream of online-state transitions.
  Stream<bool> get onChange;
}
```

- [ ] **Step 4: Run, expect PASS**

```bash
dart test test/connectivity/connectivity_monitor_test.dart
```

Expected: pass.

- [ ] **Step 5: Analyze**

```bash
dart analyze
```

Expected: zero issues. (If `public_member_api_docs` complains, the docstrings above already cover every member.)

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/connectivity/ \
        packages/flutter_universal_sync_engine/test/connectivity/
git commit -m "feat(pkg-engine): add ConnectivityMonitor interface"
```

---

## Task 12: `EngineStatus` enum

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/engine_status.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/engine_status_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_universal_sync_engine/src/engine/engine_status.dart';
import 'package:test/test.dart';

void main() {
  test('three values in declaration order', () {
    expect(EngineStatus.values, [
      EngineStatus.idle,
      EngineStatus.syncing,
      EngineStatus.error,
    ]);
  });

  test('byName round-trips for every value', () {
    for (final v in EngineStatus.values) {
      expect(EngineStatus.values.byName(v.name), v);
    }
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/engine_status_test.dart
```

- [ ] **Step 3: Implement**

```dart
/// Coarse status of the [SyncEngine], surfaced via [SyncStateSnapshot.status].
///
/// - [idle]: not currently running a cycle. May be either "online and
///   waiting for the next trigger" or "offline".
/// - [syncing]: a drain cycle (push and optionally pull) is in flight.
/// - [error]: the most recent cycle ended with at least one push or
///   pull error. The engine is still operational and will retry on
///   the next trigger; [SyncStateSnapshot.lastError] holds the message.
enum EngineStatus { idle, syncing, error }
```

- [ ] **Step 4: Run + analyze**

```bash
dart test test/engine/engine_status_test.dart
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/engine_status.dart \
        packages/flutter_universal_sync_engine/test/engine/engine_status_test.dart
git commit -m "feat(pkg-engine): add EngineStatus enum"
```

---

## Task 13: `SyncStateSnapshot` class

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/sync_state_snapshot.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/sync_state_snapshot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_universal_sync_engine/src/engine/engine_status.dart';
import 'package:flutter_universal_sync_engine/src/engine/sync_state_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('SyncStateSnapshot', () {
    test('idle factory has the expected shape', () {
      final s = SyncStateSnapshot.idle(pendingCount: 0);
      expect(s.status, EngineStatus.idle);
      expect(s.pendingCount, 0);
      expect(s.lastSyncedAt, isNull);
      expect(s.lastError, isNull);
    });

    test('syncing factory carries pendingCount', () {
      final s = SyncStateSnapshot.syncing(pendingCount: 3);
      expect(s.status, EngineStatus.syncing);
      expect(s.pendingCount, 3);
    });

    test('error factory carries lastError', () {
      final s = SyncStateSnapshot.error(
        pendingCount: 2,
        lastError: 'http 500',
      );
      expect(s.status, EngineStatus.error);
      expect(s.lastError, 'http 500');
    });

    test('copyWith replaces fields, preserves rest', () {
      final base = SyncStateSnapshot.idle(pendingCount: 0);
      final t = DateTime.utc(2026, 1, 1);
      final updated = base.copyWith(
        status: EngineStatus.syncing,
        pendingCount: 5,
        lastSyncedAt: t,
      );
      expect(updated.status, EngineStatus.syncing);
      expect(updated.pendingCount, 5);
      expect(updated.lastSyncedAt, t);
      expect(updated.lastError, isNull);
    });

    test('copyWith with sentinel-style nulling clears lastError', () {
      final base = SyncStateSnapshot.error(
        pendingCount: 1,
        lastError: 'old',
      );
      final cleared = base.copyWith(clearLastError: true);
      expect(cleared.lastError, isNull);
    });

    test('value equality and hashCode', () {
      final a = SyncStateSnapshot.idle(pendingCount: 0);
      final b = SyncStateSnapshot.idle(pendingCount: 0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/sync_state_snapshot_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:meta/meta.dart';

import 'engine_status.dart';

/// Immutable snapshot of the sync engine's state at a moment in time.
///
/// The engine emits a new `SyncStateSnapshot` on every transition (start
/// of cycle, end of cycle, error). Late subscribers immediately receive
/// the current snapshot.
@immutable
class SyncStateSnapshot {
  /// Construct directly. Prefer the named factories below.
  const SyncStateSnapshot({
    required this.status,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });

  /// The state at the start of an idle cycle (or initial state).
  factory SyncStateSnapshot.idle({
    required int pendingCount,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.idle,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
      );

  /// The state while a cycle is running.
  factory SyncStateSnapshot.syncing({
    required int pendingCount,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.syncing,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
      );

  /// Terminal state for a cycle that finished with at least one error.
  factory SyncStateSnapshot.error({
    required int pendingCount,
    required String lastError,
    DateTime? lastSyncedAt,
  }) =>
      SyncStateSnapshot(
        status: EngineStatus.error,
        pendingCount: pendingCount,
        lastSyncedAt: lastSyncedAt,
        lastError: lastError,
      );

  /// Coarse status. See [EngineStatus] for semantics.
  final EngineStatus status;

  /// Number of unsynced queue entries at emission time.
  final int pendingCount;

  /// Last time a cycle completed without errors. Null until the first
  /// successful cycle.
  final DateTime? lastSyncedAt;

  /// Error message from the most recent failed cycle, or null after a
  /// successful cycle.
  final String? lastError;

  /// Returns a copy with the listed fields replaced. Pass
  /// [clearLastError] = `true` to set [lastError] to null (the
  /// idiomatic way to express "this snapshot has cleared the prior
  /// error").
  SyncStateSnapshot copyWith({
    EngineStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearLastError = false,
  }) =>
      SyncStateSnapshot(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStateSnapshot &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          lastSyncedAt == other.lastSyncedAt &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      Object.hash(status, pendingCount, lastSyncedAt, lastError);
}
```

- [ ] **Step 4: Run + analyze**

```bash
dart test test/engine/sync_state_snapshot_test.dart
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/sync_state_snapshot.dart \
        packages/flutter_universal_sync_engine/test/engine/sync_state_snapshot_test.dart
git commit -m "feat(pkg-engine): add SyncStateSnapshot data class"
```

---

## Task 14: `TableConfig` class

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/table_config.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/table_config_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:test/test.dart';

void main() {
  test('default conflictResolver is LastWriteWinsResolver', () {
    const config = TableConfig();
    expect(config.conflictResolver, isA<LastWriteWinsResolver>());
  });

  test('accepts a custom resolver', () {
    const config = TableConfig(conflictResolver: ServerPriorityResolver());
    expect(config.conflictResolver, isA<ServerPriorityResolver>());
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/table_config_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Per-table configuration the sync engine uses when pulling changes.
///
/// Today this carries only [conflictResolver]. The class exists rather
/// than passing a bare [ConflictResolver] so future per-table options
/// (pull priority, soft-delete handling, batch size) can be added
/// without changing the engine's constructor signature.
class TableConfig {
  /// Creates a table config. Defaults to last-write-wins.
  const TableConfig({this.conflictResolver = const LastWriteWinsResolver()});

  /// Strategy invoked when a pulled remote row collides with a pending
  /// local edit. Inert when the table has no pending entries at pull
  /// time — the engine never invokes this for plain propagation.
  final ConflictResolver conflictResolver;
}
```

- [ ] **Step 4: Run + analyze**

```bash
dart test test/engine/table_config_test.dart
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/table_config.dart \
        packages/flutter_universal_sync_engine/test/engine/table_config_test.dart
git commit -m "feat(pkg-engine): add TableConfig class"
```

---

## Task 15: `defaultBackoff` function

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/backoff.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/backoff_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:test/test.dart';

void main() {
  group('defaultBackoff', () {
    test('returns 1 second for retryCount 0', () {
      expect(defaultBackoff(0), const Duration(seconds: 1));
    });

    test('doubles for each retry', () {
      expect(defaultBackoff(1), const Duration(seconds: 2));
      expect(defaultBackoff(2), const Duration(seconds: 4));
      expect(defaultBackoff(3), const Duration(seconds: 8));
      expect(defaultBackoff(4), const Duration(seconds: 16));
      expect(defaultBackoff(5), const Duration(seconds: 32));
      expect(defaultBackoff(6), const Duration(seconds: 64));
      expect(defaultBackoff(7), const Duration(seconds: 128));
      expect(defaultBackoff(8), const Duration(seconds: 256));
    });

    test('saturates at 5 minutes', () {
      const cap = Duration(minutes: 5);
      expect(defaultBackoff(9), cap);
      expect(defaultBackoff(10), cap);
      expect(defaultBackoff(100), cap);
    });

    test('treats negative input as 0', () {
      expect(defaultBackoff(-1), const Duration(seconds: 1));
      expect(defaultBackoff(-100), const Duration(seconds: 1));
    });
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/backoff_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'dart:math' as math;

/// Default backoff schedule used by the engine when a push fails.
///
/// `min(2^retryCount * 1s, 5min)`. `retryCount == 0` returns `1s`.
/// Negative input is treated as 0. Pure function — safe to call from
/// any isolate.
///
/// Override by passing a different `Duration Function(int)` to the
/// `SyncEngine` constructor's `backoff` parameter.
Duration defaultBackoff(int retryCount) {
  if (retryCount <= 0) return const Duration(seconds: 1);
  // Cap exponent before pow to avoid overflow on huge retry counts.
  final exp = math.min(retryCount, 30);
  final ms = math.pow(2, exp).toInt() * 1000;
  const capMs = 5 * 60 * 1000;
  return Duration(milliseconds: math.min(ms, capMs));
}
```

- [ ] **Step 4: Run + analyze**

```bash
dart test test/engine/backoff_test.dart
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/backoff.dart \
        packages/flutter_universal_sync_engine/test/engine/backoff_test.dart
git commit -m "feat(pkg-engine): add defaultBackoff function"
```

---

## Task 16: Test support — fakes and clock

Three test doubles plus a private `Clock` abstraction. We bundle them in one task because none has interesting independent behavior — they exist only to support later tests.

**Files (all new):**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/_clock.dart`
- Create: `packages/flutter_universal_sync_engine/test/support/fake_clock.dart`
- Create: `packages/flutter_universal_sync_engine/test/support/fake_connectivity_monitor.dart`
- Create: `packages/flutter_universal_sync_engine/test/support/fake_remote_sync_adapter.dart`

- [ ] **Step 1: Write `_clock.dart` (private package abstraction)**

```dart
import 'package:meta/meta.dart';

/// Time abstraction used by the engine internally so tests can drive
/// the clock without sleeping. Public consumers do not see this; the
/// `SyncEngine` constructor exposes a separate package-private
/// constructor variant in the same library that accepts a [Clock].
@internal
abstract class Clock {
  /// Returns the current UTC time.
  DateTime now();

  /// Returns a future that completes after [d] has elapsed on this clock.
  /// Real-time clocks delegate to `Future.delayed`; fakes can advance
  /// virtually.
  Future<void> delay(Duration d);

  /// The default real-time clock.
  static const Clock systemClock = _SystemClock();
}

class _SystemClock implements Clock {
  const _SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
  @override
  Future<void> delay(Duration d) => Future<void>.delayed(d);
}
```

- [ ] **Step 2: Write `test/support/fake_clock.dart`**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';

/// Manually advanceable clock for engine tests. Calls to [delay] return
/// futures that complete only when [advance] (or [advanceTo]) moves the
/// virtual clock past the future's deadline.
class FakeClock implements Clock {
  FakeClock({DateTime? start})
      : _now = start ?? DateTime.utc(2026, 1, 1, 12);

  DateTime _now;
  final List<_Pending> _pending = [];

  @override
  DateTime now() => _now;

  @override
  Future<void> delay(Duration d) {
    final completer = Completer<void>();
    _pending.add(_Pending(_now.add(d), completer));
    return completer.future;
  }

  /// Advances the clock by [d], completing every pending [delay] whose
  /// deadline has elapsed.
  void advance(Duration d) {
    _now = _now.add(d);
    _flush();
  }

  /// Advances the clock to a specific moment.
  void advanceTo(DateTime target) {
    if (target.isBefore(_now)) {
      throw ArgumentError.value(target, 'target', 'cannot move clock backwards');
    }
    _now = target;
    _flush();
  }

  void _flush() {
    final ready = _pending.where((p) => !p.deadline.isAfter(_now)).toList();
    _pending.removeWhere(ready.contains);
    for (final p in ready) {
      p.completer.complete();
    }
  }
}

class _Pending {
  _Pending(this.deadline, this.completer);
  final DateTime deadline;
  final Completer<void> completer;
}
```

- [ ] **Step 3: Write `test/support/fake_connectivity_monitor.dart`**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

/// Programmable [ConnectivityMonitor] for tests.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool initial = true}) : _isOnline = initial;

  bool _isOnline;
  final _ctrl = StreamController<bool>.broadcast();
  int _listenerCount = 0;

  /// How many active listeners the engine has on [onChange]. Used to
  /// assert subscription / cancellation behaviour in lifecycle tests.
  int get listenerCount => _listenerCount;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onChange => _ctrl.stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (v, sink) => sink.add(v),
        ),
      );

  /// Drives a transition. Mirrors the value to [isOnline] and emits.
  void emit(bool online) {
    _isOnline = online;
    _ctrl.add(online);
  }

  Future<void> dispose() async {
    await _ctrl.close();
  }
}
```

(The `flutter_universal_sync_engine.dart` barrel will be created in Task 23 — this import works after Task 11's source file exists, since the barrel re-export is just a convenience. If the import resolves with a "not yet exported" error before Task 23, switch the import to the direct path: `import 'package:flutter_universal_sync_engine/src/connectivity/connectivity_monitor.dart';`.)

- [ ] **Step 4: Write `test/support/fake_remote_sync_adapter.dart`**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Programmable [RemoteSyncAdapter] for tests.
class FakeRemoteSyncAdapter implements RemoteSyncAdapter {
  /// Calls to [pushOperation], in arrival order. Inspected by tests.
  final List<SyncQueueEntry> pushed = [];

  /// Each pushOperation call pops the head of [pushOutcomes]. If the
  /// queue is empty, the call succeeds. To make a call throw, push an
  /// [Exception] (or any [Object]) here.
  final List<Object?> pushOutcomes = [];

  /// Per-pull-call canned responses, keyed by table. Each list is
  /// drained head-first; once empty, subsequent calls return `[]`.
  final Map<String, List<List<Map<String, dynamic>>>> pullResponses = {};

  /// Records of (table, since) pairs the engine asked for.
  final List<({String table, DateTime? since})> pullCalls = [];

  /// Optional artificial delay applied to each [pushOperation]. Useful
  /// for testing concurrency / coalescing.
  Duration pushDelay = Duration.zero;

  @override
  Future<void> pushOperation(SyncQueueEntry entry) async {
    pushed.add(entry);
    if (pushDelay > Duration.zero) {
      await Future<void>.delayed(pushDelay);
    }
    if (pushOutcomes.isEmpty) return;
    final outcome = pushOutcomes.removeAt(0);
    if (outcome != null) {
      throw outcome;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    pullCalls.add((table: table, since: since));
    final canned = pullResponses[table];
    if (canned == null || canned.isEmpty) return const [];
    return canned.removeAt(0);
  }
}
```

- [ ] **Step 5: Run analyze (no test files yet for the doubles themselves)**

```bash
cd packages/flutter_universal_sync_engine
dart pub get
dart analyze
```

Expected: zero issues. The fakes import `flutter_universal_sync_engine.dart` (created in Task 23). If that import is unresolved at this stage, switch to the direct path noted in Step 3.

- [ ] **Step 6: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/_clock.dart \
        packages/flutter_universal_sync_engine/test/support/
git commit -m "test(pkg-engine): add Clock, FakeClock, FakeConnectivityMonitor, FakeRemoteSyncAdapter"
```

---

## Task 17: `PushPipeline` (private) + tests

The push half of the engine. Per-entity grouping, fail-stop within group, continue across groups, backoff-aware via `pendingSyncEntries(readyAt:)`.

**Files (all new):**
- Create: `packages/flutter_universal_sync_engine/lib/src/push/push_pipeline.dart`
- Create: `packages/flutter_universal_sync_engine/test/push/per_entity_grouping_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/push/backoff_skipping_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/push/idempotency_test.dart`

- [ ] **Step 1: Write `per_entity_grouping_test.dart` (FAIL initially)**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late FakeClock clock;
  late PushPipeline pipeline;

  setUp(() {
    local = InMemoryAdapter();
    remote = FakeRemoteSyncAdapter();
    clock = FakeClock();
    pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: clock,
      backoff: defaultBackoff,
    );
  });

  Future<void> enqueue(
    String qid,
    String entityId, {
    int seconds = 0,
    SyncOperation op = SyncOperation.update,
  }) =>
      local.enqueueSync(SyncQueueEntry(
        id: qid,
        table: 'users',
        entityId: entityId,
        operation: op,
        payload: {'id': entityId, 'q': qid},
        createdAt: clock.now().add(Duration(seconds: seconds)),
      ));

  test('pushes all entries when all succeed', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u2', seconds: 1);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2']);
    expect(result.succeeded, 2);
    expect(result.failed, isEmpty);
  });

  test('within a group, stops after first failure', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u1', seconds: 1);
    await enqueue('q3', 'u1', seconds: 2);
    remote.pushOutcomes.addAll([null, Exception('boom')]);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2']); // q3 not attempted
    expect(result.succeeded, 1);
    expect(result.failed.single.entry.id, 'q2');
  });

  test('failure in group A does NOT stop group B', () async {
    await enqueue('q1', 'u1', seconds: 0);
    await enqueue('q2', 'u2', seconds: 1);
    await enqueue('q3', 'u2', seconds: 2);
    remote.pushOutcomes.addAll([Exception('boom-1'), null, null]);
    final result = await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1', 'q2', 'q3']);
    expect(result.succeeded, 2);
    expect(result.failed.single.entry.id, 'q1');
  });

  test('groups are processed in earliest-created-at order', () async {
    await enqueue('q-late', 'u1', seconds: 5);
    await enqueue('q-early', 'u2', seconds: 0);
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q-early', 'q-late']);
  });

  test('within a group, entries push in created_at order', () async {
    await enqueue('q-second', 'u1', seconds: 1);
    await enqueue('q-first', 'u1', seconds: 0);
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q-first', 'q-second']);
  });

  test('successful pushes are marked synced', () async {
    await enqueue('q1', 'u1');
    await pipeline.drain();
    final pending = await local.pendingSyncEntries();
    expect(pending, isEmpty);
  });

  test('failed entry is recorded with retry_count + next_retry_at', () async {
    await enqueue('q1', 'u1');
    remote.pushOutcomes.add(Exception('http 500'));
    await pipeline.drain();
    final pending = await local.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(pending.first.retryCount, 1);
    expect(pending.first.lastError, contains('http 500'));
    expect(pending.first.nextRetryAt, isNotNull);
    // first failure → 1s backoff under defaultBackoff
    expect(
      pending.first.nextRetryAt!.difference(clock.now()),
      const Duration(seconds: 1),
    );
  });
}
```

- [ ] **Step 2: Write `backoff_skipping_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('entry with future next_retry_at is skipped', () async {
    final local = InMemoryAdapter();
    final remote = FakeRemoteSyncAdapter();
    final clock = FakeClock();
    final pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: clock,
      backoff: defaultBackoff,
    );
    await local.enqueueSync(SyncQueueEntry(
      id: 'q1',
      table: 'users',
      entityId: 'u1',
      operation: SyncOperation.update,
      payload: const {'id': 'u1'},
      createdAt: clock.now(),
      nextRetryAt: clock.now().add(const Duration(minutes: 1)),
      retryCount: 1,
    ));

    await pipeline.drain();
    expect(remote.pushed, isEmpty);

    clock.advance(const Duration(minutes: 2));
    await pipeline.drain();
    expect(remote.pushed.map((e) => e.id), ['q1']);
  });
}
```

- [ ] **Step 3: Write `idempotency_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:flutter_universal_sync_engine/src/push/push_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_remote_sync_adapter.dart';

/// Documents the trade-off in spec §6.4: the push and the mark-synced
/// are not bundled in one transaction. If the process dies between the
/// two, the next drain re-pushes. Most adapters' operations are
/// idempotent (PUT, DELETE, server-side UPSERT), which is why we accept
/// the trade-off.
void main() {
  test('mark-synced not running causes a re-push next drain', () async {
    final local = _CrashAfterPushAdapter();
    final remote = FakeRemoteSyncAdapter();
    final clock = FakeClock();
    final pipeline = PushPipeline(
      localDb: local,
      remote: remote,
      clock: clock,
      backoff: defaultBackoff,
    );

    await local.enqueueSync(SyncQueueEntry(
      id: 'q1',
      table: 'users',
      entityId: 'u1',
      operation: SyncOperation.update,
      payload: const {'id': 'u1'},
      createdAt: clock.now(),
    ));

    local.crashOnNextMarkSynced = true;
    // Pipeline should swallow the crash and surface a failed entry.
    final firstDrain = await pipeline.drain();
    expect(remote.pushed, hasLength(1));
    expect(firstDrain.succeeded, 0);

    // Re-enable mark-synced and drain again. The same q1 should re-push.
    local.crashOnNextMarkSynced = false;
    await pipeline.drain();
    expect(remote.pushed, hasLength(2));
    expect(remote.pushed.last.id, 'q1');
  });
}

class _CrashAfterPushAdapter extends InMemoryAdapter {
  bool crashOnNextMarkSynced = false;

  @override
  Future<void> markSynced(String queueEntryId) async {
    if (crashOnNextMarkSynced) {
      crashOnNextMarkSynced = false;
      throw StateError('simulated crash between push and mark-synced');
    }
    return super.markSynced(queueEntryId);
  }
}
```

- [ ] **Step 4: Run all three tests, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/push/
```

Expected: compile failure on missing `PushPipeline`.

- [ ] **Step 5: Implement `PushPipeline`**

Create `lib/src/push/push_pipeline.dart`:

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../engine/_clock.dart';

/// Result of a single [PushPipeline.drain] invocation. Aggregated by
/// the engine into the next snapshot. Internal to the engine package;
/// not part of the public API.
@internal
class PushDrainResult {
  PushDrainResult({
    required this.succeeded,
    required this.skippedDueToBackoff,
    required this.failed,
  });
  final int succeeded;
  final int skippedDueToBackoff;
  final List<({SyncQueueEntry entry, Object error})> failed;
}

/// Drains the local sync queue. Per-entity serial; cross-entity
/// continuation on failure. See spec §6.
@internal
class PushPipeline {
  PushPipeline({
    required this.localDb,
    required this.remote,
    required this.clock,
    required this.backoff,
  });

  final LocalDatabaseAdapter localDb;
  final RemoteSyncAdapter remote;
  final Clock clock;
  final Duration Function(int retryCount) backoff;

  Future<PushDrainResult> drain() async {
    final entries = await localDb.pendingSyncEntries(readyAt: clock.now());

    // Compute total pending excluding what we'll attempt this cycle to
    // report skippedDueToBackoff. The set complement of `entries`
    // against the unfiltered queue equals "deferred by backoff".
    final allPending = await localDb.pendingSyncEntries();
    final readyIds = entries.map((e) => e.id).toSet();
    final skipped = allPending.where((e) => !readyIds.contains(e.id)).length;

    // Group by entity_id, preserving relative order within each group
    // and tracking each group's earliest createdAt for outer ordering.
    final groups = <String, List<SyncQueueEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.entityId, () => []).add(entry);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) =>
          groups[a]!.first.createdAt.compareTo(groups[b]!.first.createdAt));

    var succeeded = 0;
    final failed = <({SyncQueueEntry entry, Object error})>[];

    for (final entityId in sortedKeys) {
      for (final entry in groups[entityId]!) {
        try {
          await remote.pushOperation(entry);
          await localDb.markSynced(entry.id);
          succeeded++;
        } catch (error) {
          failed.add((entry: entry, error: error));
          // Best-effort failure record. Swallow errors from the failure
          // path itself so we surface the original push error to the
          // caller and can move on to the next group.
          try {
            await localDb.recordSyncFailure(
              entry.id,
              error.toString(),
              nextRetryAt:
                  clock.now().add(backoff(entry.retryCount + 1)),
            );
          } catch (_) {
            // Ignore: the engine's snapshot will surface lastError.
          }
          break; // stop this group; continue to next group
        }
      }
    }

    return PushDrainResult(
      succeeded: succeeded,
      skippedDueToBackoff: skipped,
      failed: failed,
    );
  }
}
```

- [ ] **Step 6: Run all push tests, expect PASS**

```bash
dart test test/push/
dart analyze
```

Expected: all pass; analyze clean.

- [ ] **Step 7: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/push/ \
        packages/flutter_universal_sync_engine/test/push/
git commit -m "feat(pkg-engine): add PushPipeline with per-entity grouping and backoff"
```

---

## Task 18: `PullPipeline` (private) + tests

Pull half of the engine. Conflict detection only when local has a pending entry; cursor advancement last; per-row transactions.

**Files (all new):**
- Create: `packages/flutter_universal_sync_engine/lib/src/meta/meta_keys.dart`
- Create: `packages/flutter_universal_sync_engine/lib/src/pull/pull_pipeline.dart`
- Create: `packages/flutter_universal_sync_engine/test/pull/conflict_detection_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/pull/cursor_advancement_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/pull/empty_pull_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/meta/cursor_storage_test.dart`

- [ ] **Step 1: Write `meta_keys.dart`**

```dart
/// Engine-defined keys used in the `_sync_meta` KV table. Internal to
/// the engine package; consumers do not read these directly.
class MetaKeys {
  MetaKeys._();

  /// Returns the per-table pull cursor key, e.g. `pull_cursor:users`.
  /// Cursor value is a `DateTime.toIso8601String()` of the most recent
  /// `updated_at` seen in any successful pull for that table.
  static String pullCursor(String table) => 'pull_cursor:$table';
}
```

- [ ] **Step 2: Write `cursor_storage_test.dart`**

```dart
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:test/test.dart';

void main() {
  test('pullCursor key format', () {
    expect(MetaKeys.pullCursor('users'), 'pull_cursor:users');
    expect(MetaKeys.pullCursor('orders'), 'pull_cursor:orders');
  });

  test('round-trip via InMemoryAdapter', () async {
    final adapter = InMemoryAdapter();
    final iso = DateTime.utc(2026, 1, 1).toIso8601String();
    await adapter.setMeta(MetaKeys.pullCursor('users'), iso);
    expect(await adapter.getMeta(MetaKeys.pullCursor('users')), iso);
  });
}
```

- [ ] **Step 3: Write `conflict_detection_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:flutter_universal_sync_engine/src/pull/pull_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late PullPipeline pipeline;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    pipeline = PullPipeline(localDb: local, remote: remote);
  });

  test('no pending → resolver NOT called, server wins', () async {
    final calls = <String>[];
    final config = TableConfig(
      conflictResolver: _RecordingResolver(calls),
    );
    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'u1',
          'name': 'remote',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 200,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ]
    ];

    await pipeline.pullTable('users', config);

    expect(calls, isEmpty);
    final row = await local.getById('users', 'u1');
    expect(row!['name'], 'remote');
  });

  test('local has pending → resolver IS called with (local, remote)', () async {
    await local.upsert('users', {
      SyncColumns.id: 'u1',
      'name': 'local',
      SyncColumns.createdAt: 100,
      SyncColumns.updatedAt: 150,
      SyncColumns.deletedAt: null,
      SyncColumns.isSynced: 0,
      SyncColumns.syncStatus: 'pending',
    });
    await local.enqueueSync(SyncQueueEntry(
      id: 'q1',
      table: 'users',
      entityId: 'u1',
      operation: SyncOperation.update,
      payload: const {'id': 'u1', 'name': 'local'},
      createdAt: DateTime.utc(2026, 1, 1, 12),
    ));
    final calls = <String>[];
    final config = TableConfig(
      conflictResolver: _RecordingResolver(calls, picks: 'remote'),
    );

    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'u1',
          'name': 'remote',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 250,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ]
    ];

    await pipeline.pullTable('users', config);

    expect(calls, ['called with local=local remote=remote']);
    // Resolver picked "remote" → row is now remote.
    final row = await local.getById('users', 'u1');
    expect(row!['name'], 'remote');
    // Queue entry payload was rewritten to the merged map.
    final pending = await local.pendingSyncEntries();
    expect(pending.single.payload['name'], 'remote');
  });

  test('remote row for unknown entity → upsert as insert', () async {
    remote.pullResponses['users'] = [
      [
        {
          SyncColumns.id: 'new',
          'name': 'fresh',
          SyncColumns.createdAt: 100,
          SyncColumns.updatedAt: 100,
          SyncColumns.deletedAt: null,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
        },
      ]
    ];

    await pipeline.pullTable('users', const TableConfig());

    expect(await local.getById('users', 'new'), isNotNull);
  });
}

class _RecordingResolver implements ConflictResolver {
  _RecordingResolver(this.calls, {this.picks = 'local'});
  final List<String> calls;
  final String picks; // 'local' or 'remote'

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    calls.add('called with local=${local['name']} remote=${remote['name']}');
    return picks == 'remote' ? remote : local;
  }
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 4: Write `cursor_advancement_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:flutter_universal_sync_engine/src/pull/pull_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late PullPipeline pipeline;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    pipeline = PullPipeline(localDb: local, remote: remote);
  });

  Map<String, dynamic> remoteRow(String id, int updatedAt) => {
        SyncColumns.id: id,
        'name': id,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 1,
        SyncColumns.syncStatus: 'synced',
      };

  test('cursor advances to max(updated_at) on success', () async {
    remote.pullResponses['users'] = [
      [remoteRow('u1', 200), remoteRow('u2', 350), remoteRow('u3', 300)]
    ];

    await pipeline.pullTable('users', const TableConfig());

    final cursor = await local.getMeta(MetaKeys.pullCursor('users'));
    expect(cursor, isNotNull);
    expect(
      DateTime.parse(cursor!).millisecondsSinceEpoch,
      350,
    );
  });

  test('cursor unchanged when remote returns no rows', () async {
    remote.pullResponses['users'] = [<Map<String, dynamic>>[]];
    await pipeline.pullTable('users', const TableConfig());
    expect(await local.getMeta(MetaKeys.pullCursor('users')), isNull);
  });

  test('cursor passed back as `since` on subsequent pulls', () async {
    remote.pullResponses['users'] = [
      [remoteRow('u1', 1000)],
      [remoteRow('u2', 2000)],
    ];
    await pipeline.pullTable('users', const TableConfig());
    await pipeline.pullTable('users', const TableConfig());

    expect(remote.pullCalls.first.since, isNull);
    expect(
      remote.pullCalls.last.since!.millisecondsSinceEpoch,
      1000,
    );
  });
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 5: Write `empty_pull_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:flutter_universal_sync_engine/src/pull/pull_pipeline.dart';
import 'package:test/test.dart';

import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('empty remoteRows → no transactions, cursor unchanged', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', const [
        SyncColumns.id,
        SyncColumns.createdAt,
        SyncColumns.updatedAt,
        SyncColumns.deletedAt,
        SyncColumns.isSynced,
        SyncColumns.syncStatus,
      ]);
    final remote = FakeRemoteSyncAdapter()
      ..pullResponses['users'] = [<Map<String, dynamic>>[]];
    final pipeline = PullPipeline(localDb: local, remote: remote);

    await pipeline.pullTable('users', const TableConfig());

    expect(remote.pullCalls, hasLength(1));
    expect(await local.getMeta(MetaKeys.pullCursor('users')), isNull);
  });
}
```

- [ ] **Step 6: Run pull/meta tests, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/pull/ test/meta/
```

Expected: compile failure on missing `PullPipeline`.

- [ ] **Step 7: Implement `PullPipeline`**

Create `lib/src/pull/pull_pipeline.dart`:

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../engine/table_config.dart';
import '../meta/meta_keys.dart';

/// Pulls deltas for a single table and applies them to the local DB.
/// Invokes [TableConfig.conflictResolver] only when the incoming row's
/// entity has a pending local queue entry. See spec §7.
@internal
class PullPipeline {
  PullPipeline({required this.localDb, required this.remote});

  final LocalDatabaseAdapter localDb;
  final RemoteSyncAdapter remote;

  Future<void> pullTable(String table, TableConfig config) async {
    final cursorStr = await localDb.getMeta(MetaKeys.pullCursor(table));
    final since = cursorStr == null ? null : DateTime.parse(cursorStr);

    final remoteRows = await remote.pullChanges(table, since);
    if (remoteRows.isEmpty) return;

    for (final remoteRow in remoteRows) {
      final entityId = remoteRow[SyncColumns.id] as String;
      await localDb.transaction(() async {
        final localRow = await localDb.getById(table, entityId);
        final pending = await localDb.pendingForEntity(table, entityId);

        if (pending.isEmpty || localRow == null) {
          // No competing local edit (or row didn't exist). Server wins.
          await localDb.upsert(table, remoteRow);
        } else {
          final merged = config.conflictResolver.resolve(localRow, remoteRow);
          await localDb.upsert(table, merged);
          await localDb.rewriteQueuePayload(pending.last.id, merged);
        }
      });
    }

    // Advance cursor only after every per-row apply succeeded.
    final maxUpdatedAt = remoteRows
        .map((r) => (r[SyncColumns.updatedAt] as int?) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maxUpdatedAt > 0) {
      await localDb.setMeta(
        MetaKeys.pullCursor(table),
        DateTime.fromMillisecondsSinceEpoch(maxUpdatedAt, isUtc: true)
            .toIso8601String(),
      );
    }
  }
}
```

- [ ] **Step 8: Run pull/meta tests, expect PASS**

```bash
dart test test/pull/ test/meta/
dart analyze
```

- [ ] **Step 9: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/pull/ \
        packages/flutter_universal_sync_engine/lib/src/meta/ \
        packages/flutter_universal_sync_engine/test/pull/ \
        packages/flutter_universal_sync_engine/test/meta/
git commit -m "feat(pkg-engine): add PullPipeline with conflict detection and cursor advance"
```

---

## Task 19: `SyncEngine` skeleton — constructor, fields, dispose

The public class. We build it in three tasks: this one establishes the constructor, fields, the snapshot stream foundation, and `dispose()`. Tasks 20 and 21 add `start`/`stop` and `syncNow` respectively.

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart`

- [ ] **Step 1: Write the file**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../connectivity/connectivity_monitor.dart';
import '../pull/pull_pipeline.dart';
import '../push/push_pipeline.dart';
import 'backoff.dart';
import '_clock.dart';
import 'engine_status.dart';
import 'sync_state_snapshot.dart';
import 'table_config.dart';

/// Sync engine for the flutter_universal_sync family. Drives the
/// hybrid (auto + explicit) drain loop, exposes a state-snapshot
/// stream, owns push and pull pipelines.
///
/// See `docs/superpowers/specs/2026-04-30-sync-engine-design.md`.
class SyncEngine {
  /// Public constructor. The engine uses a system clock internally.
  SyncEngine({
    required LocalDatabaseAdapter localDb,
    required RemoteSyncAdapter remote,
    required ConnectivityMonitor connectivity,
    required Map<String, TableConfig> tables,
    Duration drainInterval = const Duration(minutes: 5),
    Duration Function(int retryCount) backoff = defaultBackoff,
    IdGenerator idGenerator = const UuidV4Generator(),
  }) : this._withClock(
          localDb: localDb,
          remote: remote,
          connectivity: connectivity,
          tables: Map.unmodifiable(tables),
          drainInterval: drainInterval,
          backoff: backoff,
          idGenerator: idGenerator,
          clock: Clock.systemClock,
        );

  /// Test-only constructor that injects a [Clock]. Mark the call site
  /// with `@visibleForTesting` if you call this from outside the engine
  /// package.
  @visibleForTesting
  SyncEngine.withClock({
    required LocalDatabaseAdapter localDb,
    required RemoteSyncAdapter remote,
    required ConnectivityMonitor connectivity,
    required Map<String, TableConfig> tables,
    required Clock clock,
    Duration drainInterval = const Duration(minutes: 5),
    Duration Function(int retryCount) backoff = defaultBackoff,
    IdGenerator idGenerator = const UuidV4Generator(),
  }) : this._withClock(
          localDb: localDb,
          remote: remote,
          connectivity: connectivity,
          tables: Map.unmodifiable(tables),
          drainInterval: drainInterval,
          backoff: backoff,
          idGenerator: idGenerator,
          clock: clock,
        );

  SyncEngine._withClock({
    required this.localDb,
    required this.remote,
    required this.connectivity,
    required this.tables,
    required this.drainInterval,
    required this.backoff,
    required this.idGenerator,
    required this.clock,
  })  : _push = PushPipeline(
          localDb: localDb,
          remote: remote,
          clock: clock,
          backoff: backoff,
        ),
        _pull = PullPipeline(localDb: localDb, remote: remote),
        _stateController = StreamController<SyncStateSnapshot>.broadcast() {
    _current = SyncStateSnapshot.idle(pendingCount: 0);
  }

  /// The local database adapter the engine drives. Public so tests and
  /// subclasses can introspect; not part of the typical user-facing API.
  final LocalDatabaseAdapter localDb;

  /// The remote sync adapter the engine drives.
  final RemoteSyncAdapter remote;

  /// Connectivity monitor; the engine subscribes on `start()`.
  final ConnectivityMonitor connectivity;

  /// Per-table configuration: conflict resolver and (future) options.
  final Map<String, TableConfig> tables;

  /// How often the auto-drain loop fires when running.
  final Duration drainInterval;

  /// Backoff function applied to failed pushes.
  final Duration Function(int retryCount) backoff;

  /// ID generator (currently unused inside the engine; reserved for
  /// future internal IDs and exposed so DI containers can wire one
  /// instance across packages).
  final IdGenerator idGenerator;

  /// Clock — system clock in production, fake clock in tests.
  @visibleForTesting
  final Clock clock;

  final PushPipeline _push;
  final PullPipeline _pull;
  final StreamController<SyncStateSnapshot> _stateController;
  late SyncStateSnapshot _current;
  bool _disposed = false;

  /// Snapshot stream. Broadcast; late subscribers immediately receive
  /// the current snapshot.
  Stream<SyncStateSnapshot> get state async* {
    if (_disposed) return;
    yield _current;
    yield* _stateController.stream;
  }

  /// Synchronous accessor for non-stream consumers.
  SyncStateSnapshot get current => _current;

  /// Disposes the engine. Cancels timer and connectivity subscription
  /// (added in Task 20), closes the snapshot stream, marks the engine
  /// unusable. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateController.close();
  }

  /// Emits a new snapshot on the stream and updates [current]. Internal
  /// to the engine; pipelines call this via the cycle loop.
  void _emit(SyncStateSnapshot snapshot) {
    _current = snapshot;
    if (!_stateController.isClosed) {
      _stateController.add(snapshot);
    }
  }
}
```

- [ ] **Step 2: Run analyze (no tests yet for this task; lifecycle test follows in Task 20)**

```bash
cd packages/flutter_universal_sync_engine
dart analyze
```

Expected: zero issues. (Some fields like `_push`, `_pull`, `_emit` are not yet referenced — `unused_field` / `unused_element` warnings would be ignored by the strict-* analyzer; if the analyzer flags them, suppress with `// ignore: unused_field` until Task 20/21 wires them up. Prefer to leave them unsuppressed if `package:lints/recommended` does not flag them.)

- [ ] **Step 3: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart
git commit -m "feat(pkg-engine): add SyncEngine skeleton with state stream and dispose"
```

---

## Task 20: `SyncEngine.start` / `stop` + drain loop wiring

Adds the auto-drain loop. Connectivity-online transition + periodic timer trigger one cycle each (debounced via a single in-flight Future). Mark this task complete only when lifecycle tests pass.

**Files:**
- Modify: `packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart`
- Create: `packages/flutter_universal_sync_engine/lib/src/engine/_drain_loop.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/sync_engine_lifecycle_test.dart`

- [ ] **Step 1: Write `sync_engine_lifecycle_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late FakeConnectivityMonitor connectivity;
  late FakeClock clock;
  late SyncEngine engine;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    connectivity = FakeConnectivityMonitor(initial: true);
    clock = FakeClock();
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await connectivity.dispose();
  });

  test('initial snapshot is idle with pendingCount 0', () async {
    expect(engine.current.status, EngineStatus.idle);
    expect(engine.current.pendingCount, 0);
  });

  test('start is idempotent: second call does not double-listen', () async {
    await engine.start();
    final once = connectivity.listenerCount;
    await engine.start();
    expect(connectivity.listenerCount, once);
  });

  test('stop is idempotent and cancels listeners', () async {
    await engine.start();
    await engine.stop();
    expect(connectivity.listenerCount, 0);
    await engine.stop(); // no-op, no throw
  });

  test('start fires one immediate cycle when online', () async {
    await engine.enqueueTestEntry('u1');
    await engine.start();
    // Allow microtasks to drain.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, hasLength(1));
  });

  test('start does NOT fire a cycle when offline', () async {
    connectivity = FakeConnectivityMonitor(initial: false);
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    await engine.enqueueTestEntry('u1');
    await engine.start();
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, isEmpty);
  });

  test('online transition fires a cycle', () async {
    connectivity = FakeConnectivityMonitor(initial: false);
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    await engine.start();
    await engine.enqueueTestEntry('u1');
    connectivity.emit(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(remote.pushed, hasLength(1));
  });

  test('stop awaits in-flight cycle', () async {
    remote.pushDelay = const Duration(milliseconds: 50);
    await engine.enqueueTestEntry('u1');
    await engine.start();
    final stopFuture = engine.stop();
    await stopFuture; // must not throw, must not return until cycle ends
    expect(remote.pushed, hasLength(1));
  });
}

extension on SyncEngine {
  /// Convenience for tests: enqueues a single insert against `users`.
  Future<void> enqueueTestEntry(String entityId) async {
    await localDb.transaction(() async {
      await localDb.upsert('users', {
        SyncColumns.id: entityId,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: 100,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      });
      await localDb.enqueueSync(SyncQueueEntry(
        id: 'q-$entityId',
        table: 'users',
        entityId: entityId,
        operation: SyncOperation.insert,
        payload: {SyncColumns.id: entityId},
        createdAt: clock.now(),
      ));
    });
  }
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/sync_engine_lifecycle_test.dart
```

Expected: failure on missing `start` / `stop`.

- [ ] **Step 3: Add `start` / `stop` and the drain loop scaffold**

In `lib/src/engine/sync_engine.dart`, add three private fields below `_disposed`:

```dart
  StreamSubscription<bool>? _connectivitySub;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _started = false;
```

Add methods inside the class (before `_emit`):

```dart
  /// Starts the auto-drain loop. Idempotent.
  Future<void> start() async {
    if (_disposed) {
      throw StateError('SyncEngine.start called after dispose');
    }
    if (_started) return;
    _started = true;

    _connectivitySub = connectivity.onChange.listen((online) {
      if (online) {
        unawaited(_scheduleCycle(pull: false));
      }
    });
    _timer = Timer.periodic(drainInterval, (_) {
      unawaited(_scheduleCycle(pull: false));
    });

    if (connectivity.isOnline) {
      unawaited(_scheduleCycle(pull: false));
    }
  }

  /// Stops the auto-drain loop. Awaits any in-flight cycle. Idempotent.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // _runCycle already handles its own errors; ignore.
      }
    }
  }

  Future<void> _scheduleCycle({required bool pull}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _runCycle(pull: pull);
    _inFlight = future;
    future.whenComplete(() {
      _inFlight = null;
    });
    return future;
  }

  Future<void> _runCycle({required bool pull}) async {
    if (_disposed) return;
    if (!connectivity.isOnline) {
      _emit(await _snapshotIdle());
      return;
    }
    _emit(await _snapshotSyncing());
    Object? lastError;
    try {
      final pushResult = await _push.drain();
      if (pushResult.failed.isNotEmpty) {
        lastError = pushResult.failed.last.error;
      }
      if (pull) {
        for (final entry in tables.entries) {
          try {
            await _pull.pullTable(entry.key, entry.value);
          } catch (e) {
            lastError = e;
          }
        }
      }
    } catch (e) {
      lastError = e;
    }
    if (lastError == null) {
      _emit((await _snapshotIdle()).copyWith(
        lastSyncedAt: clock.now(),
        clearLastError: true,
      ));
    } else {
      _emit(SyncStateSnapshot.error(
        pendingCount: await _countPending(),
        lastError: lastError.toString(),
        lastSyncedAt: _current.lastSyncedAt,
      ));
    }
  }

  Future<SyncStateSnapshot> _snapshotIdle() async => SyncStateSnapshot.idle(
        pendingCount: await _countPending(),
        lastSyncedAt: _current.lastSyncedAt,
      );

  Future<SyncStateSnapshot> _snapshotSyncing() async =>
      SyncStateSnapshot.syncing(
        pendingCount: await _countPending(),
        lastSyncedAt: _current.lastSyncedAt,
      );

  Future<int> _countPending() async {
    final pending = await localDb.pendingSyncEntries();
    return pending.length;
  }
```

In the existing `dispose()`, before `_stateController.close()`, add cleanup:

```dart
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {}
    }
```

The `_drain_loop.dart` file mentioned in §10's file structure stays empty for now — the loop logic ended up small enough to live in `sync_engine.dart`. Delete the `_drain_loop.dart` reference from the structure note in §10 of the spec when reading; not creating the file is fine.

- [ ] **Step 4: Run lifecycle tests, expect PASS**

```bash
dart test test/engine/sync_engine_lifecycle_test.dart
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart \
        packages/flutter_universal_sync_engine/test/engine/sync_engine_lifecycle_test.dart
git commit -m "feat(pkg-engine): SyncEngine.start/stop with debounced auto-drain loop"
```

---

## Task 21: `SyncEngine.syncNow` + cycle execution

Adds the explicit trigger and verifies the snapshot stream + cycle execution.

**Files:**
- Modify: `packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/sync_engine_drain_test.dart`

- [ ] **Step 1: Write `sync_engine_drain_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  late InMemoryAdapter local;
  late FakeRemoteSyncAdapter remote;
  late FakeConnectivityMonitor connectivity;
  late FakeClock clock;
  late SyncEngine engine;

  setUp(() {
    local = InMemoryAdapter()..registerTable('users', _userColumns);
    remote = FakeRemoteSyncAdapter();
    connectivity = FakeConnectivityMonitor(initial: true);
    clock = FakeClock();
    engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await connectivity.dispose();
  });

  Future<void> seed(String id) async {
    await local.transaction(() async {
      await local.upsert('users', {
        SyncColumns.id: id,
        SyncColumns.createdAt: 100,
        SyncColumns.updatedAt: 100,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      });
      await local.enqueueSync(SyncQueueEntry(
        id: 'q-$id',
        table: 'users',
        entityId: id,
        operation: SyncOperation.insert,
        payload: {SyncColumns.id: id},
        createdAt: clock.now(),
      ));
    });
  }

  test('syncNow emits idle → syncing → idle', () async {
    await seed('u1');
    final snapshots = <EngineStatus>[];
    final sub = engine.state.listen((s) => snapshots.add(s.status));
    await engine.syncNow();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(snapshots, [EngineStatus.idle, EngineStatus.syncing, EngineStatus.idle]);
  });

  test('two syncNow calls coalesce into one cycle', () async {
    remote.pushDelay = const Duration(milliseconds: 30);
    await seed('u1');
    final f1 = engine.syncNow();
    final f2 = engine.syncNow();
    await Future.wait([f1, f2]);
    expect(remote.pushed, hasLength(1));
  });

  test('late subscriber receives the current snapshot immediately', () async {
    final received = <EngineStatus>[];
    final sub = engine.state.listen((s) => received.add(s.status));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(received, [EngineStatus.idle]);
  });

  test('snapshot pendingCount reflects queue size', () async {
    await seed('u1');
    await seed('u2');
    expect(engine.current.pendingCount, 0);
    final cycle = engine.syncNow();
    // Capture the syncing snapshot mid-cycle
    SyncStateSnapshot? snap;
    final sub = engine.state.listen((s) {
      if (s.status == EngineStatus.syncing) snap = s;
    });
    await cycle;
    await sub.cancel();
    expect(snap, isNotNull);
    expect(snap!.pendingCount, 2);
  });

  test('error in push surfaces as EngineStatus.error with lastError', () async {
    await seed('u1');
    remote.pushOutcomes.add(Exception('boom'));
    await engine.syncNow();
    expect(engine.current.status, EngineStatus.error);
    expect(engine.current.lastError, contains('boom'));
  });

  test('successful syncNow updates lastSyncedAt', () async {
    await seed('u1');
    final before = engine.current.lastSyncedAt;
    await engine.syncNow();
    expect(engine.current.lastSyncedAt, isNot(before));
    expect(engine.current.lastSyncedAt, clock.now());
  });
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 2: Run, expect FAIL**

```bash
cd packages/flutter_universal_sync_engine
dart test test/engine/sync_engine_drain_test.dart
```

Expected: failure on missing `syncNow`.

- [ ] **Step 3: Implement `syncNow`**

In `lib/src/engine/sync_engine.dart`, add after `stop()`:

```dart
  /// Explicit trigger. Runs a drain cycle.
  ///
  /// `pull: false` (default) → push only.
  /// `pull: true` → push, then pull every registered table.
  ///
  /// Concurrent calls coalesce: if a cycle is already in flight, the
  /// returned Future resolves when that cycle completes.
  Future<void> syncNow({bool pull = false}) {
    if (_disposed) {
      throw StateError('SyncEngine.syncNow called after dispose');
    }
    return _scheduleCycle(pull: pull);
  }
```

- [ ] **Step 4: Run drain tests + lifecycle tests, expect PASS**

```bash
dart test test/engine/
dart analyze
```

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/src/engine/sync_engine.dart \
        packages/flutter_universal_sync_engine/test/engine/sync_engine_drain_test.dart
git commit -m "feat(pkg-engine): SyncEngine.syncNow with concurrent-call coalescing"
```

---

## Task 22: Engine integration tests (offline + multi-table pull)

Two final behavioural tests. No production-code changes; they pin spec-required behaviour the prior tests didn't cover.

**Files (new):**
- Create: `packages/flutter_universal_sync_engine/test/engine/sync_engine_offline_test.dart`
- Create: `packages/flutter_universal_sync_engine/test/engine/sync_engine_pull_test.dart`

- [ ] **Step 1: Write `sync_engine_offline_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('offline syncNow is a no-op snapshot, queue untouched', () async {
    final local = InMemoryAdapter()..registerTable('users', _userColumns);
    final remote = FakeRemoteSyncAdapter();
    final connectivity = FakeConnectivityMonitor(initial: false);
    final clock = FakeClock();
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {'users': TableConfig()},
      clock: clock,
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await local.transaction(() async {
      await local.enqueueSync(SyncQueueEntry(
        id: 'q1',
        table: 'users',
        entityId: 'u1',
        operation: SyncOperation.insert,
        payload: const {SyncColumns.id: 'u1'},
        createdAt: clock.now(),
      ));
    });

    await engine.syncNow();
    expect(remote.pushed, isEmpty);
    expect(remote.pullCalls, isEmpty);
    final pending = await local.pendingSyncEntries();
    expect(pending, hasLength(1));
    expect(engine.current.status, EngineStatus.idle);
  });
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 2: Write `sync_engine_pull_test.dart`**

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';
import '../support/fake_connectivity_monitor.dart';
import '../support/fake_remote_sync_adapter.dart';

void main() {
  test('syncNow(pull: true) iterates every registered table', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', _userColumns)
      ..registerTable('orders', _userColumns);
    final remote = FakeRemoteSyncAdapter()
      ..pullResponses['users'] = [<Map<String, dynamic>>[]]
      ..pullResponses['orders'] = [<Map<String, dynamic>>[]];
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {
        'users': TableConfig(),
        'orders': TableConfig(),
      },
      clock: FakeClock(),
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await engine.syncNow(pull: true);

    expect(remote.pullCalls.map((c) => c.table), ['users', 'orders']);
  });

  test('error in pulling one table does not stop other tables', () async {
    final local = InMemoryAdapter()
      ..registerTable('users', _userColumns)
      ..registerTable('orders', _userColumns);
    final remote = _BrokenUsersRemote()
      ..pullResponses['orders'] = [<Map<String, dynamic>>[]];
    final connectivity = FakeConnectivityMonitor(initial: true);
    final engine = SyncEngine.withClock(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {
        'users': TableConfig(),
        'orders': TableConfig(),
      },
      clock: FakeClock(),
    );
    addTearDown(() async {
      await engine.dispose();
      await connectivity.dispose();
    });

    await engine.syncNow(pull: true);

    expect(remote.pullCalls.map((c) => c.table).toSet(), {'users', 'orders'});
    expect(engine.current.status, EngineStatus.error);
    expect(engine.current.lastError, contains('users-down'));
  });
}

class _BrokenUsersRemote extends FakeRemoteSyncAdapter {
  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    pullCalls.add((table: table, since: since));
    if (table == 'users') {
      throw Exception('users-down');
    }
    final canned = pullResponses[table];
    if (canned == null || canned.isEmpty) return const [];
    return canned.removeAt(0);
  }
}

const _userColumns = [
  SyncColumns.id,
  SyncColumns.createdAt,
  SyncColumns.updatedAt,
  SyncColumns.deletedAt,
  SyncColumns.isSynced,
  SyncColumns.syncStatus,
];
```

- [ ] **Step 3: Run + analyze**

```bash
cd packages/flutter_universal_sync_engine
dart test
dart analyze
```

Expected: full test suite passes; analyze clean.

- [ ] **Step 4: Commit**

```bash
git add packages/flutter_universal_sync_engine/test/engine/sync_engine_offline_test.dart \
        packages/flutter_universal_sync_engine/test/engine/sync_engine_pull_test.dart
git commit -m "test(pkg-engine): add offline-noop and multi-table pull integration tests"
```

---

## Task 23: Engine production barrel + smoke test

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/flutter_universal_sync_engine.dart`
- Create: `packages/flutter_universal_sync_engine/test/barrel_test.dart`

- [ ] **Step 1: Write the barrel**

```dart
/// Sync engine for the flutter_universal_sync family.
///
/// See the spec at
/// `docs/superpowers/specs/2026-04-30-sync-engine-design.md`
/// and `README.md` for usage.
library;

export 'src/connectivity/connectivity_monitor.dart';
export 'src/engine/backoff.dart';
export 'src/engine/engine_status.dart';
export 'src/engine/sync_engine.dart' show SyncEngine;
export 'src/engine/sync_state_snapshot.dart';
export 'src/engine/table_config.dart';
```

The `show SyncEngine` clause hides the package-private `SyncEngine.withClock` constructor and the `_drain_loop`-style internals from public consumers.

- [ ] **Step 2: Write `barrel_test.dart`**

```dart
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

void main() {
  test('public API surface is reachable through the barrel', () {
    // Just referencing each type is the smoke test. If the barrel ever
    // drops one accidentally, this stops compiling.
    expect(EngineStatus.idle, isNotNull);
    expect(SyncStateSnapshot.idle(pendingCount: 0), isNotNull);
    expect(const TableConfig(), isNotNull);
    expect(defaultBackoff(0), isNotNull);
    expect(ConnectivityMonitor, isNotNull);
    expect(SyncEngine, isNotNull);
  });
}
```

- [ ] **Step 3: Run + analyze**

```bash
cd packages/flutter_universal_sync_engine
dart test test/barrel_test.dart
dart analyze
```

- [ ] **Step 4: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/flutter_universal_sync_engine.dart \
        packages/flutter_universal_sync_engine/test/barrel_test.dart
git commit -m "feat(pkg-engine): add production barrel export"
```

---

## Task 24: Engine testing barrel

**Files:**
- Create: `packages/flutter_universal_sync_engine/lib/testing.dart`
- Move: `test/support/fake_connectivity_monitor.dart` → `lib/src/testing/fake_connectivity_monitor.dart`
- Move: `test/support/fake_remote_sync_adapter.dart` → `lib/src/testing/fake_remote_sync_adapter.dart`

The fakes need to live under `lib/` to be re-exportable. Tests stay where they are; their imports change to point at the new location through the testing barrel.

- [ ] **Step 1: Move the fake files into `lib/src/testing/`**

```bash
cd packages/flutter_universal_sync_engine
mkdir -p lib/src/testing
git mv test/support/fake_connectivity_monitor.dart lib/src/testing/fake_connectivity_monitor.dart
git mv test/support/fake_remote_sync_adapter.dart lib/src/testing/fake_remote_sync_adapter.dart
```

The `FakeClock` stays in `test/support/` — it's a test-only utility that consumers don't import.

- [ ] **Step 2: Write `lib/testing.dart`**

```dart
/// Test doubles for downstream packages that integration-test against
/// the engine's contracts. Import this barrel from your `dev_dependencies`
/// — never from production code.
library;

export 'src/testing/fake_connectivity_monitor.dart';
export 'src/testing/fake_remote_sync_adapter.dart';
```

- [ ] **Step 3: Update imports in the engine's own tests**

For every file under `packages/flutter_universal_sync_engine/test/` that imported `'../support/fake_connectivity_monitor.dart'` or `'../support/fake_remote_sync_adapter.dart'`, replace with:

```dart
import 'package:flutter_universal_sync_engine/testing.dart';
```

(The `FakeClock` import stays as `'../support/fake_clock.dart'`.)

Files to update (search for `fake_connectivity_monitor.dart` or `fake_remote_sync_adapter.dart`):
- `test/push/per_entity_grouping_test.dart`
- `test/push/backoff_skipping_test.dart`
- `test/push/idempotency_test.dart`
- `test/pull/conflict_detection_test.dart`
- `test/pull/cursor_advancement_test.dart`
- `test/pull/empty_pull_test.dart`
- `test/engine/sync_engine_lifecycle_test.dart`
- `test/engine/sync_engine_drain_test.dart`
- `test/engine/sync_engine_offline_test.dart`
- `test/engine/sync_engine_pull_test.dart`

- [ ] **Step 4: Run full test suite + analyze**

```bash
dart test
dart analyze
```

Expected: all tests pass; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add packages/flutter_universal_sync_engine/lib/testing.dart \
        packages/flutter_universal_sync_engine/lib/src/testing/ \
        packages/flutter_universal_sync_engine/test/
git commit -m "feat(pkg-engine): add testing barrel and move fakes under lib/"
```

---

## Task 25: Engine CI workflow

**Files:**
- Create: `.github/workflows/engine.yml`

- [ ] **Step 1: Write the workflow**

```yaml
name: pkg-engine

on:
  push:
    branches: [main]
    paths:
      - 'packages/flutter_universal_sync_engine/**'
      - 'packages/flutter_universal_sync_core/**'
      - '.github/workflows/engine.yml'
  pull_request:
    paths:
      - 'packages/flutter_universal_sync_engine/**'
      - 'packages/flutter_universal_sync_core/**'
      - '.github/workflows/engine.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/flutter_universal_sync_engine
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: '3.4.0'
      - name: Get dependencies
        run: dart pub get
      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed lib test
      - name: Analyze
        run: dart analyze --fatal-infos
      - name: Run tests with coverage
        run: dart test --coverage=coverage
      - name: Format coverage
        run: |
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov --in=coverage --out=coverage/lcov.info \
            --report-on=lib --check-ignore
      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: engine-coverage
          path: packages/flutter_universal_sync_engine/coverage/lcov.info
```

The path filter includes the core package because the engine depends on it via `dependency_overrides`; a core change can break the engine's CI.

- [ ] **Step 2: Sanity-check formatting locally**

```bash
cd packages/flutter_universal_sync_engine
dart format --output=none --set-exit-if-changed lib test
```

Expected: no diffs. If diffs exist, run `dart format lib test` and amend the previous task's commit (or commit as a separate `style(pkg-engine):` commit).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/engine.yml
git commit -m "ci: add flutter_universal_sync_engine workflow"
```

---

## Task 26: Engine README

**Files:**
- Create: `packages/flutter_universal_sync_engine/README.md`

- [ ] **Step 1: Write the README**

```markdown
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
```

- [ ] **Step 2: Sanity-check the markdown renders**

```bash
cd packages/flutter_universal_sync_engine
ls README.md
# Optionally view in your editor or via a markdown previewer.
```

- [ ] **Step 3: Commit**

```bash
git add packages/flutter_universal_sync_engine/README.md
git commit -m "docs(pkg-engine): add package README with wiring snippet"
```

---

## Task 27: Engine 0.1.0 finalize — CHANGELOG, dry-run

**Files:**
- Modify: `packages/flutter_universal_sync_engine/CHANGELOG.md`

- [ ] **Step 1: Replace the stub CHANGELOG with the final entry**

Replace the `## 0.1.0 — Unreleased` section with:

```markdown
## 0.1.0 — 2026-04-30

Initial release. Sync engine for the `flutter_universal_sync` family.

### Added
- `SyncEngine` with hybrid lifecycle (`start`/`stop` + `syncNow`).
- `Stream<SyncStateSnapshot>` with BehaviorSubject semantics; coarse
  `EngineStatus` (idle / syncing / error).
- `ConnectivityMonitor` abstract interface (consumers supply impl).
- `TableConfig` with per-table `ConflictResolver` (extensible).
- `defaultBackoff` exponential schedule, capped at 5 minutes.
- Push pipeline: per-entity grouping, fail-stop within group,
  cross-group continuation, `next_retry_at`-aware skipping.
- Pull pipeline: per-table delta fetch via `since` cursor, conflict
  resolver invoked only when local has a pending edit, idempotent
  cursor advancement.
- Test doubles: `FakeConnectivityMonitor`, `FakeRemoteSyncAdapter`
  (exported via `package:flutter_universal_sync_engine/testing.dart`).
```

- [ ] **Step 2: Run `dart pub publish --dry-run`**

```bash
cd packages/flutter_universal_sync_engine
dart pub publish --dry-run
```

Expected: passes with at most the same homepage placeholder warning the core package has. The `dependency_overrides` block in `pubspec.yaml` is OK for dry-run; before actual publish it must be removed (Plan 14 owns publishing).

- [ ] **Step 3: Run full test + analyze + coverage**

```bash
dart test --coverage=coverage
dart analyze
```

Expected: all tests pass; analyze clean. Spot-check coverage by inspecting `coverage/lcov.info`.

- [ ] **Step 4: Commit**

```bash
git add packages/flutter_universal_sync_engine/CHANGELOG.md
git commit -m "docs(pkg-engine): finalize 0.1.0 CHANGELOG"
```

---

## Task 28: Demo — add engine + connectivity_plus deps + `ConnectivityPlusMonitor`

**Files:**
- Modify: `examples/sync_demo/pubspec.yaml`
- Create: `examples/sync_demo/lib/sync/connectivity_plus_monitor.dart`

- [ ] **Step 1: Add deps to `examples/sync_demo/pubspec.yaml`**

Under `dependencies:` add:

```yaml
  connectivity_plus: ^6.0.0
  flutter_universal_sync_engine:
    path: ../../packages/flutter_universal_sync_engine
```

(The existing `flutter_universal_sync_core` path-dep stays.)

- [ ] **Step 2: Write `connectivity_plus_monitor.dart`**

Create `examples/sync_demo/lib/sync/connectivity_plus_monitor.dart` with the snippet from §8 of the spec (also reproduced in the engine README). Verbatim:

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

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onChange => _controller.stream;

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
```

- [ ] **Step 3: Resolve deps + analyze**

```bash
cd examples/sync_demo
flutter pub get
flutter analyze
```

Expected: zero issues.

- [ ] **Step 4: Commit**

```bash
git add examples/sync_demo/pubspec.yaml \
        examples/sync_demo/pubspec.lock \
        examples/sync_demo/lib/sync/connectivity_plus_monitor.dart
git commit -m "feat(sync_demo): add engine + connectivity_plus deps and ConnectivityPlusMonitor"
```

---

## Task 29: Demo — migrate to `SyncEngine`

The demo's existing ad-hoc drain loop (`SyncRunner`) is replaced by a `SyncEngine` instance. The demo's `SqfliteSyncAdapter` already implements `LocalDatabaseAdapter` 0.1.0; here we extend it to satisfy 0.2.0.

**Files:**
- Modify: `examples/sync_demo/lib/sync/sqflite_sync_adapter.dart` (add 0.2.0 methods + `next_retry_at` column + `_sync_meta` table)
- Modify: `examples/sync_demo/lib/main.dart` (or wherever the engine is constructed; replace `SyncRunner` with `SyncEngine`)
- Delete: `examples/sync_demo/lib/sync/sync_runner.dart`

- [ ] **Step 1: Extend `SqfliteSyncAdapter` to 0.2.0**

Add the new methods. Pattern after the InMemoryAdapter implementations from Tasks 3–8:

- `Future<void> upsert(String table, Map<String, dynamic> data)` — `INSERT OR REPLACE`.
- `Future<String?> getMeta(String key)` / `setMeta(...)` / `deleteMeta(...)` — backed by a new `_sync_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` table.
- `Future<List<SyncQueueEntry>> pendingForEntity(...)` — `SELECT ... WHERE table = ? AND entity_id = ? AND synced = 0 ORDER BY created_at ASC`.
- `Future<void> rewriteQueuePayload(...)` — `UPDATE sync_queue SET payload = ? WHERE id = ?`.
- Extend `pendingSyncEntries({int? limit, DateTime? readyAt})` to include `next_retry_at IS NULL OR next_retry_at <= ?` when `readyAt != null`.
- Extend `recordSyncFailure(..., {DateTime? nextRetryAt, bool incrementRetryCount = true})` to update `retry_count = retry_count + 1` and write `next_retry_at` when given.

Add the schema migrations:
- `ALTER TABLE sync_queue ADD COLUMN next_retry_at INTEGER;`
- `CREATE TABLE IF NOT EXISTS _sync_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);`

If the demo uses a hand-rolled `_db.execute(...)` schema setup, append these statements there. Bump the SQLite `version` integer if the demo uses `onUpgrade` migration.

- [ ] **Step 2: Replace `SyncRunner` with `SyncEngine` wiring**

In wherever `SyncRunner` is instantiated (likely `main.dart` or a dedicated bootstrapping file), replace its construction with:

```dart
final engine = SyncEngine(
  localDb: sqfliteAdapter,
  remote: restAdapter,
  connectivity: ConnectivityPlusMonitor(),
  tables: const {
    'things': TableConfig(conflictResolver: LastWriteWinsResolver()),
  },
);
await engine.start();
```

The demo's existing pull-to-refresh handler should call `engine.syncNow(pull: true)` instead of `syncRunner.run()`. The status badge UI should listen to `engine.state` and inspect `snap.status`/`snap.pendingCount`.

- [ ] **Step 3: Delete `sync_runner.dart`**

```bash
git rm examples/sync_demo/lib/sync/sync_runner.dart
```

(If the file is referenced from anywhere else in the demo, remove those imports.)

- [ ] **Step 4: Resolve deps + analyze**

```bash
cd examples/sync_demo
flutter pub get
flutter analyze
```

Expected: zero issues.

- [ ] **Step 5: Commit**

```bash
git add examples/sync_demo/lib/
git commit -m "refactor(sync_demo): migrate to SyncEngine, extend SqfliteSyncAdapter to core 0.2.0"
```

---

## Task 30: Verify demo end-to-end — gate

This task produces no file output. It verifies the engine and the migrated demo work together against the existing `examples/test-backend` Node + SQLite REST server.

- [ ] **Step 1: Start the test backend**

```bash
cd examples/test-backend
npm install
npm start
# server listens on http://localhost:4567
```

- [ ] **Step 2: Run the demo**

```bash
cd examples/sync_demo
flutter run -d macos --dart-define=SYNC_DEMO_BACKEND=http://localhost:4567
```

(Substitute the platform of your choice; the demo already supports macOS, iOS, Android.)

- [ ] **Step 3: Manual smoke checklist**

Tick each:
- [ ] App launches without errors.
- [ ] AppBar status badge shows `idle`.
- [ ] FAB-add a thing → status flips to `syncing` → back to `idle` within ~1s.
- [ ] After sync, the row's status icon is `cloud_done`.
- [ ] Disable network (turn off Wi-Fi or stop the test backend) → add another thing → row icon shows `cloud_upload` (pending). Status badge eventually shows `error` with a `lastError` message.
- [ ] Re-enable network → engine auto-drains within seconds (because connectivity transition triggers a cycle).
- [ ] Pull-to-refresh in the list → status flips to `syncing` and the engine pulls from `/sync/things`.
- [ ] Make a change on a second device or via `curl` directly to the backend → pull-to-refresh in the demo → row appears.

- [ ] **Step 4: If anything fails, file it as a follow-up**

Each failure becomes a separate issue / commit, not a fix in this task. The plan's success criterion is "demo round-trips end-to-end"; tweaking demo UX further is out of scope.

- [ ] **Step 5: Commit (only if any minor fixes were necessary; otherwise skip)**

```bash
# example, only if the smoke checklist surfaced trivial wiring fixes:
git add examples/sync_demo/
git commit -m "fix(sync_demo): minor wiring fixes from end-to-end smoke run"
```

---

## Done.

Plan complete. Spec coverage:

| Spec section | Tasks |
|---|---|
| §3 Public API | 11, 12, 13, 14, 15, 19, 20, 21, 23 |
| §4 Core 0.2.0 | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 |
| §5 Drain loop | 19, 20, 21 |
| §6 Push pipeline | 17 |
| §7 Pull pipeline | 18 |
| §8 Connectivity reference | 26 (README), 28 (demo) |
| §9 Testing | 16, 17, 18, 20, 21, 22, 25 |
| §10 Public surface + barrels | 23, 24 |
| §11 Known limitations | 26 (README) |
| §12 Success criteria | 9, 27, 30 |

