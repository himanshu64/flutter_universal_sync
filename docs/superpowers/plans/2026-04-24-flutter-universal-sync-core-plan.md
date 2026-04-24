# `flutter_universal_sync_core` v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish-ready the `flutter_universal_sync_core` Dart package — the contracts layer that every downstream adapter and the sync engine will depend on.

**Architecture:** Pure-Dart package living at `packages/flutter_universal_sync_core/` inside a new monorepo. No Flutter dependency. No execution logic — only interface contracts, simple data types, three built-in conflict resolvers, and a reusable `LocalDatabaseAdapterContract` test suite. Two barrel exports: production (`flutter_universal_sync_core.dart`) and testing (`testing.dart`).

**Tech Stack:** Dart SDK ^3.4.0; runtime dep `uuid: ^4.4.0`; dev deps `test: ^1.25.0`, `lints: ^4.0.0`, `coverage: ^1.8.0`.

**Spec reference:** [docs/superpowers/specs/2026-04-24-flutter-universal-sync-core-design.md](../specs/2026-04-24-flutter-universal-sync-core-design.md)

---

## Prerequisites

- Dart SDK 3.4+ installed (`dart --version` → `Dart SDK version: 3.4.0` or higher)
- Working directory: `/Users/himanshusharma/Documents/flutter_universal_sync`
- Repo already initialized — `git log --oneline` must show `docs: design spec for flutter_universal_sync_core v1`

If any of those is missing, stop and resolve before Task 0.

---

## Task Layout (preview)

| # | Task | Outputs |
|---|------|---------|
| 0 | Monorepo scaffolding | `.gitignore`, root `README.md` |
| 1 | Core package skeleton | `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, stub `CHANGELOG.md` |
| 2 | `SyncOperation` enum | entity + test |
| 3 | `SyncStatus` enum | entity + test |
| 4 | `SyncEntity` abstract base class | entity + test |
| 5 | `SyncQueueEntry` data class | entity + test |
| 6 | `SyncColumns` constants | schema + test |
| 7 | `SyncException` hierarchy | errors + test |
| 8 | `IdGenerator` + `UuidV4Generator` | id gen + test |
| 9 | `ConflictResolver` + `LastWriteWinsResolver` | interface + first built-in + test |
| 10 | `ServerPriorityResolver` + `ClientPriorityResolver` | other two built-ins + tests |
| 11 | `LocalDatabaseAdapter` interface | abstract class |
| 12 | `RemoteSyncAdapter` interface | abstract class |
| 13 | Production barrel export | `flutter_universal_sync_core.dart` + smoke test |
| 14 | In-memory stub adapter | `test/support/in_memory_adapter.dart` |
| 15 | Contract suite — domain CRUD | contract suite + test against stub |
| 16 | Contract suite — queue operations | contract suite + test |
| 17 | Contract suite — transaction atomicity | contract suite + test |
| 18 | Contract suite — schema validation | contract suite + test |
| 19 | Testing barrel export | `testing.dart` |
| 20 | CI workflow (GitHub Actions) | `.github/workflows/core.yml` |
| 21 | Core package README | `README.md` |
| 22 | `dart pub publish --dry-run` verification | (no file output; gate) |
| 23 | CHANGELOG finalization | `CHANGELOG.md` 0.1.0 entry |

---

## File Structure

```
flutter_universal_sync/                                     (monorepo root, git repo)
├── .gitignore                                              Task 0
├── README.md                                               Task 0
├── .github/workflows/core.yml                              Task 20
├── docs/superpowers/
│   ├── specs/2026-04-24-flutter-universal-sync-core-design.md    (exists)
│   └── plans/2026-04-24-flutter-universal-sync-core-plan.md      (this file)
└── packages/
    └── flutter_universal_sync_core/                        Task 1
        ├── pubspec.yaml                                    Task 1
        ├── analysis_options.yaml                           Task 1
        ├── LICENSE                                         Task 1
        ├── CHANGELOG.md                                    Tasks 1 stub, 23 final
        ├── README.md                                       Task 21
        ├── lib/
        │   ├── src/
        │   │   ├── entities/
        │   │   │   ├── sync_operation.dart                 Task 2
        │   │   │   ├── sync_status.dart                    Task 3
        │   │   │   ├── sync_entity.dart                    Task 4
        │   │   │   └── sync_queue_entry.dart               Task 5
        │   │   ├── schema/sync_columns.dart                Task 6
        │   │   ├── errors/sync_errors.dart                 Task 7
        │   │   ├── id/id_generator.dart                    Task 8
        │   │   ├── conflict/
        │   │   │   ├── conflict_resolver.dart              Task 9
        │   │   │   ├── last_write_wins_resolver.dart       Task 9
        │   │   │   ├── server_priority_resolver.dart       Task 10
        │   │   │   └── client_priority_resolver.dart       Task 10
        │   │   ├── adapters/
        │   │   │   ├── local_database_adapter.dart         Task 11
        │   │   │   └── remote_sync_adapter.dart            Task 12
        │   │   └── testing/
        │   │       └── local_database_adapter_contract.dart  Tasks 15–18
        │   ├── flutter_universal_sync_core.dart            Task 13
        │   └── testing.dart                                Task 19
        └── test/
            ├── support/in_memory_adapter.dart              Task 14
            ├── entities/sync_operation_test.dart           Task 2
            ├── entities/sync_status_test.dart              Task 3
            ├── entities/sync_entity_test.dart              Task 4
            ├── entities/sync_queue_entry_test.dart         Task 5
            ├── schema/sync_columns_test.dart               Task 6
            ├── errors/sync_errors_test.dart                Task 7
            ├── id/id_generator_test.dart                   Task 8
            ├── conflict/last_write_wins_resolver_test.dart Task 9
            ├── conflict/server_priority_resolver_test.dart Task 10
            ├── conflict/client_priority_resolver_test.dart Task 10
            ├── barrel_test.dart                            Task 13
            └── contract_suite_test.dart                    Tasks 15–18
```

---

## Conventions

- **Commits:** Conventional Commits (`feat:`, `test:`, `chore:`, `docs:`, `ci:`, `refactor:`). Co-author trailer is optional.
- **Test commands:** from the package dir (`packages/flutter_universal_sync_core`). Use `dart test path/to/file.dart` or `dart test --name "pattern"`.
- **Analyze:** every task ends by running `dart analyze` from the package dir and expecting zero issues.
- **Commit cadence:** one commit per task (test + impl combined) unless a task specifies otherwise.

---

## Task 0: Monorepo scaffolding

**Files:**
- Create: `/Users/himanshusharma/Documents/flutter_universal_sync/.gitignore`
- Create: `/Users/himanshusharma/Documents/flutter_universal_sync/README.md`

- [ ] **Step 1: Write the `.gitignore`**

Contents of `/Users/himanshusharma/Documents/flutter_universal_sync/.gitignore`:

```gitignore
# Dart
.dart_tool/
.packages
build/
pubspec.lock
*.iml
.idea/
.vscode/

# Coverage
coverage/

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 2: Write the root README**

Contents of `/Users/himanshusharma/Documents/flutter_universal_sync/README.md`:

```markdown
# flutter_universal_sync

Federated package family for offline-first sync in Flutter. Monorepo.

## Packages

| Package | Status |
|---------|--------|
| `flutter_universal_sync_core` | In development (Plan 1) |

See [docs/superpowers/](docs/superpowers/) for specs and plans.

## License

MIT
```

- [ ] **Step 3: Verify layout and commit**

Run:
```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
ls -la
git status
```
Expected: `.gitignore`, `README.md`, `docs/`, `.git/` are present.

```bash
git add .gitignore README.md
git commit -m "chore: scaffold monorepo root"
```

---

## Task 1: Core package skeleton

**Files:**
- Create: `packages/flutter_universal_sync_core/pubspec.yaml`
- Create: `packages/flutter_universal_sync_core/analysis_options.yaml`
- Create: `packages/flutter_universal_sync_core/LICENSE`
- Create: `packages/flutter_universal_sync_core/CHANGELOG.md`

- [ ] **Step 1: Create the package directory**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
mkdir -p packages/flutter_universal_sync_core/lib/src/entities \
         packages/flutter_universal_sync_core/lib/src/schema \
         packages/flutter_universal_sync_core/lib/src/errors \
         packages/flutter_universal_sync_core/lib/src/id \
         packages/flutter_universal_sync_core/lib/src/conflict \
         packages/flutter_universal_sync_core/lib/src/adapters \
         packages/flutter_universal_sync_core/lib/src/testing \
         packages/flutter_universal_sync_core/test/entities \
         packages/flutter_universal_sync_core/test/schema \
         packages/flutter_universal_sync_core/test/errors \
         packages/flutter_universal_sync_core/test/id \
         packages/flutter_universal_sync_core/test/conflict \
         packages/flutter_universal_sync_core/test/support
```

- [ ] **Step 2: Write `pubspec.yaml`**

Path: `packages/flutter_universal_sync_core/pubspec.yaml`

```yaml
name: flutter_universal_sync_core
description: Core contracts for the flutter_universal_sync offline-first sync package family. Defines the SyncEntity, adapter interfaces, conflict resolver, schema constants, and error hierarchy shared by every adapter package.
version: 0.1.0
homepage: https://github.com/REPLACE_ME/flutter_universal_sync
repository: https://github.com/REPLACE_ME/flutter_universal_sync
issue_tracker: https://github.com/REPLACE_ME/flutter_universal_sync/issues

environment:
  sdk: ^3.4.0

dependencies:
  uuid: ^4.4.0

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
  coverage: ^1.8.0
```

Note: `REPLACE_ME` in the URLs will be replaced when the user provides a GitHub org before first publish. Leave it as `REPLACE_ME` for now — Task 22's `dart pub publish --dry-run` will flag it and the user will supply the value then.

- [ ] **Step 3: Write `analysis_options.yaml`**

Path: `packages/flutter_universal_sync_core/analysis_options.yaml`

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    todo: warning
    invalid_annotation_target: ignore

linter:
  rules:
    - avoid_print
    - prefer_const_constructors
    - prefer_final_locals
    - require_trailing_commas
    - sort_pub_dependencies
    - public_member_api_docs
```

- [ ] **Step 4: Write `LICENSE` (MIT)**

Path: `packages/flutter_universal_sync_core/LICENSE`

```
MIT License

Copyright (c) 2026 flutter_universal_sync contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Write stub `CHANGELOG.md`**

Path: `packages/flutter_universal_sync_core/CHANGELOG.md`

```markdown
# Changelog

## [Unreleased]

Implementation in progress — see `docs/superpowers/plans/2026-04-24-flutter-universal-sync-core-plan.md`.
```

- [ ] **Step 6: Install deps and verify**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart pub get
dart analyze
```

Expected:
- `dart pub get` completes without error (may warn about missing README — ignore; Task 21 adds it).
- `dart analyze` reports `No issues found!` (nothing to analyze yet; that's fine).

- [ ] **Step 7: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/
git commit -m "chore(core): scaffold package skeleton"
```

---

## Task 2: `SyncOperation` enum

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/entities/sync_operation.dart`
- Test: `packages/flutter_universal_sync_core/test/entities/sync_operation_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/entities/sync_operation_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/entities/sync_operation.dart';
import 'package:test/test.dart';

void main() {
  group('SyncOperation', () {
    test('exposes exactly three values in declaration order', () {
      expect(SyncOperation.values, equals([
        SyncOperation.insert,
        SyncOperation.update,
        SyncOperation.delete,
      ]));
    });

    test('name strings are stable (used for queue persistence)', () {
      expect(SyncOperation.insert.name, equals('insert'));
      expect(SyncOperation.update.name, equals('update'));
      expect(SyncOperation.delete.name, equals('delete'));
    });

    test('byName parses the canonical names', () {
      expect(SyncOperation.values.byName('insert'), SyncOperation.insert);
      expect(SyncOperation.values.byName('update'), SyncOperation.update);
      expect(SyncOperation.values.byName('delete'), SyncOperation.delete);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/entities/sync_operation_test.dart
```
Expected: compilation failure — `Target of URI doesn't exist: 'package:.../sync_operation.dart'`.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/entities/sync_operation.dart`

```dart
/// The kind of mutation a queued sync entry represents.
///
/// The string [name] is persisted in the local sync queue and must remain
/// stable across versions — changing an existing value is a breaking change.
enum SyncOperation { insert, update, delete }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/entities/sync_operation_test.dart
dart analyze
```
Expected: all 3 tests pass; `dart analyze` reports no issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/entities/sync_operation.dart \
        packages/flutter_universal_sync_core/test/entities/sync_operation_test.dart
git commit -m "feat(core): add SyncOperation enum"
```

---

## Task 3: `SyncStatus` enum

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/entities/sync_status.dart`
- Test: `packages/flutter_universal_sync_core/test/entities/sync_status_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/entities/sync_status_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/entities/sync_status.dart';
import 'package:test/test.dart';

void main() {
  group('SyncStatus', () {
    test('exposes four values in declaration order', () {
      expect(SyncStatus.values, equals([
        SyncStatus.pending,
        SyncStatus.syncing,
        SyncStatus.synced,
        SyncStatus.failed,
      ]));
    });

    test('name strings are stable (used for row persistence)', () {
      expect(SyncStatus.pending.name, equals('pending'));
      expect(SyncStatus.syncing.name, equals('syncing'));
      expect(SyncStatus.synced.name, equals('synced'));
      expect(SyncStatus.failed.name, equals('failed'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/entities/sync_status_test.dart
```
Expected: URI-doesn't-exist compile error.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/entities/sync_status.dart`

```dart
/// Lifecycle status of a domain row with respect to remote sync.
///
/// Persisted on every [SyncEntity] via the `sync_status` column. The string
/// [name] is persisted and must remain stable.
enum SyncStatus { pending, syncing, synced, failed }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/entities/sync_status_test.dart
dart analyze
```
Expected: tests pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/entities/sync_status.dart \
        packages/flutter_universal_sync_core/test/entities/sync_status_test.dart
git commit -m "feat(core): add SyncStatus enum"
```

---

## Task 4: `SyncEntity` abstract base class

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/entities/sync_entity.dart`
- Test: `packages/flutter_universal_sync_core/test/entities/sync_entity_test.dart`

Abstract classes don't have runtime behavior on their own, so the test writes a minimal concrete subclass (`_FakeEntity`) and verifies the contract through it.

- [ ] **Step 1: Write the failing test**

Path: `test/entities/sync_entity_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/entities/sync_entity.dart';
import 'package:flutter_universal_sync_core/src/entities/sync_status.dart';
import 'package:test/test.dart';

class _FakeEntity extends SyncEntity {
  _FakeEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = false,
    this.syncStatus = SyncStatus.pending,
    this.extra = const {},
  });

  @override final String id;
  @override final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final DateTime? deletedAt;
  @override final bool isSynced;
  @override final SyncStatus syncStatus;
  final Map<String, dynamic> extra;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    'deleted_at': deletedAt?.toUtc().millisecondsSinceEpoch,
    'is_synced': isSynced ? 1 : 0,
    'sync_status': syncStatus.name,
    ...extra,
  };
}

void main() {
  group('SyncEntity', () {
    test('exposes the six sync fields via getters', () {
      final now = DateTime.utc(2026, 4, 24, 12, 0, 0);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
      );
      expect(entity.id, 'abc');
      expect(entity.createdAt, now);
      expect(entity.updatedAt, now);
      expect(entity.deletedAt, isNull);
      expect(entity.isSynced, isFalse);
      expect(entity.syncStatus, SyncStatus.pending);
    });

    test('toMap includes all sync columns plus subclass fields', () {
      final now = DateTime.utc(2026, 4, 24);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
        extra: const {'name': 'apple'},
      );
      final map = entity.toMap();
      expect(map['id'], 'abc');
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['updated_at'], now.millisecondsSinceEpoch);
      expect(map['deleted_at'], isNull);
      expect(map['is_synced'], 0);
      expect(map['sync_status'], 'pending');
      expect(map['name'], 'apple');
    });

    test('deletedAt set indicates soft delete', () {
      final now = DateTime.utc(2026, 4, 24);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
        deletedAt: now.add(const Duration(hours: 1)),
      );
      expect(entity.deletedAt, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/entities/sync_entity_test.dart
```
Expected: compile error — `sync_entity.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/entities/sync_entity.dart`

```dart
import 'sync_status.dart';

/// Base class every domain entity synced by `flutter_universal_sync` extends.
///
/// Carries the six sync metadata fields required by the package. Subclasses
/// own their domain fields and provide [toMap] (and by convention a
/// `fromMap`/named constructor). Subclasses must also populate [id],
/// [createdAt], and [updatedAt] — the package does not generate them here;
/// use an [IdGenerator] to produce ids at the repository boundary.
abstract class SyncEntity {
  /// UUIDv4 identifier — client-generated at insert time, stable forever.
  String get id;

  /// Wall-clock creation time (UTC, ms precision).
  DateTime get createdAt;

  /// Wall-clock last-update time (UTC, ms precision).
  DateTime get updatedAt;

  /// `null` = live; non-null = soft-deleted at the wall-clock time given.
  /// Soft-deleted rows are never hard-removed locally; the row persists
  /// so the deletion can be communicated to every remote.
  DateTime? get deletedAt;

  /// `true` once a remote backend has acknowledged the latest change.
  bool get isSynced;

  /// Lifecycle state of the most recent sync attempt.
  SyncStatus get syncStatus;

  /// Serializes the entity, including every key in [SyncColumns.required]
  /// with correctly-typed values, plus any subclass-specific fields.
  Map<String, dynamic> toMap();
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/entities/sync_entity_test.dart
dart analyze
```
Expected: 3 tests pass; no analyzer issues. The `public_member_api_docs` lint is satisfied by the doc comments on each getter.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/entities/sync_entity.dart \
        packages/flutter_universal_sync_core/test/entities/sync_entity_test.dart
git commit -m "feat(core): add SyncEntity abstract base class"
```

---

## Task 5: `SyncQueueEntry` data class

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/entities/sync_queue_entry.dart`
- Test: `packages/flutter_universal_sync_core/test/entities/sync_queue_entry_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/entities/sync_queue_entry_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/entities/sync_operation.dart';
import 'package:flutter_universal_sync_core/src/entities/sync_queue_entry.dart';
import 'package:test/test.dart';

void main() {
  group('SyncQueueEntry', () {
    final createdAt = DateTime.utc(2026, 4, 24, 10, 0, 0);

    SyncQueueEntry make({
      String id = 'q1',
      String table = 'products',
      String entityId = 'p1',
      SyncOperation operation = SyncOperation.insert,
      Map<String, dynamic> payload = const {'name': 'apple'},
      int retryCount = 0,
      String? lastError,
      bool synced = false,
    }) =>
        SyncQueueEntry(
          id: id,
          table: table,
          entityId: entityId,
          operation: operation,
          payload: payload,
          createdAt: createdAt,
          retryCount: retryCount,
          lastError: lastError,
          synced: synced,
        );

    test('constructor applies documented defaults', () {
      final entry = SyncQueueEntry(
        id: 'q1',
        table: 'products',
        entityId: 'p1',
        operation: SyncOperation.insert,
        payload: const {'name': 'apple'},
        createdAt: createdAt,
      );
      expect(entry.retryCount, 0);
      expect(entry.lastError, isNull);
      expect(entry.synced, isFalse);
    });

    test('copyWith replaces only the provided fields', () {
      final original = make();
      final copy = original.copyWith(synced: true, lastError: 'boom');
      expect(copy.id, original.id);
      expect(copy.table, original.table);
      expect(copy.entityId, original.entityId);
      expect(copy.operation, original.operation);
      expect(copy.payload, original.payload);
      expect(copy.createdAt, original.createdAt);
      expect(copy.retryCount, original.retryCount);
      expect(copy.synced, isTrue);
      expect(copy.lastError, 'boom');
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      final original = make(
        retryCount: 2,
        lastError: 'prev attempt failed',
        synced: true,
      );
      final reconstructed = SyncQueueEntry.fromMap(original.toMap());
      expect(reconstructed, equals(original));
    });

    test('toMap serialises operation as name and createdAt as millis', () {
      final entry = make(operation: SyncOperation.update);
      final map = entry.toMap();
      expect(map['operation'], 'update');
      expect(map['created_at'], createdAt.millisecondsSinceEpoch);
      expect(map['synced'], 0);
    });

    test('equality and hashCode are field-based', () {
      expect(make(), equals(make()));
      expect(make().hashCode, equals(make().hashCode));
      expect(make(), isNot(equals(make(id: 'different'))));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/entities/sync_queue_entry_test.dart
```
Expected: compile error — file not found.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/entities/sync_queue_entry.dart`

```dart
import 'sync_operation.dart';

/// One queued local mutation awaiting push to a remote backend.
///
/// Per-op queue: each [insert]/[update]/[delete] on the repository produces
/// one entry. The entry is persisted locally in the same transaction as the
/// domain row write (see `LocalDatabaseAdapter.transaction`).
///
/// [retryCount] and [lastError] are populated by the sync engine
/// (`flutter_universal_sync_engine`, Plan 2); Plan 1 only defines them.
class SyncQueueEntry {
  /// Creates a queue entry. [retryCount] defaults to 0; [synced] to false;
  /// [lastError] to null.
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

  /// UUID of this queue row. Distinct from [entityId].
  final String id;

  /// Name of the target user table.
  final String table;

  /// Identifier of the row being synced.
  final String entityId;

  /// Which mutation this entry represents.
  final SyncOperation operation;

  /// Full row snapshot at enqueue time. Not a diff.
  final Map<String, dynamic> payload;

  /// When the entry was enqueued (wall-clock UTC).
  final DateTime createdAt;

  /// How many push attempts have already failed for this entry.
  final int retryCount;

  /// Error message from the most recent failed push, if any.
  final String? lastError;

  /// `true` after the remote adapter has acknowledged the push.
  final bool synced;

  /// Returns a copy with the listed fields replaced.
  SyncQueueEntry copyWith({
    SyncOperation? operation,
    Map<String, dynamic>? payload,
    int? retryCount,
    String? lastError,
    bool? synced,
  }) =>
      SyncQueueEntry(
        id: id,
        table: table,
        entityId: entityId,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError ?? this.lastError,
        synced: synced ?? this.synced,
      );

  /// Serializes for persistence. `operation` becomes a stable name string;
  /// `createdAt` becomes millisecondsSinceEpoch; `synced` becomes 0/1.
  Map<String, dynamic> toMap() => {
        'id': id,
        'table': table,
        'entity_id': entityId,
        'operation': operation.name,
        'payload': payload,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'retry_count': retryCount,
        'last_error': lastError,
        'synced': synced ? 1 : 0,
      };

  /// Reconstructs from a map produced by [toMap].
  factory SyncQueueEntry.fromMap(Map<String, dynamic> m) => SyncQueueEntry(
        id: m['id'] as String,
        table: m['table'] as String,
        entityId: m['entity_id'] as String,
        operation: SyncOperation.values.byName(m['operation'] as String),
        payload: Map<String, dynamic>.from(m['payload'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
        retryCount: (m['retry_count'] as int?) ?? 0,
        lastError: m['last_error'] as String?,
        synced: (m['synced'] as int?) == 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueEntry &&
          id == other.id &&
          table == other.table &&
          entityId == other.entityId &&
          operation == other.operation &&
          _mapEquals(payload, other.payload) &&
          createdAt == other.createdAt &&
          retryCount == other.retryCount &&
          lastError == other.lastError &&
          synced == other.synced;

  @override
  int get hashCode => Object.hash(
        id,
        table,
        entityId,
        operation,
        Object.hashAll(payload.entries
            .map((e) => Object.hash(e.key, e.value))),
        createdAt,
        retryCount,
        lastError,
        synced,
      );
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/entities/sync_queue_entry_test.dart
dart analyze
```
Expected: 5 tests pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/entities/sync_queue_entry.dart \
        packages/flutter_universal_sync_core/test/entities/sync_queue_entry_test.dart
git commit -m "feat(core): add SyncQueueEntry data class"
```

---

## Task 6: `SyncColumns` constants

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/schema/sync_columns.dart`
- Test: `packages/flutter_universal_sync_core/test/schema/sync_columns_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/schema/sync_columns_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/schema/sync_columns.dart';
import 'package:test/test.dart';

void main() {
  group('SyncColumns', () {
    test('required list contains the six canonical column names', () {
      expect(SyncColumns.required, [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_synced',
        'sync_status',
      ]);
    });

    test('individual constants match the list', () {
      expect(SyncColumns.id, 'id');
      expect(SyncColumns.createdAt, 'created_at');
      expect(SyncColumns.updatedAt, 'updated_at');
      expect(SyncColumns.deletedAt, 'deleted_at');
      expect(SyncColumns.isSynced, 'is_synced');
      expect(SyncColumns.syncStatus, 'sync_status');
    });

    test('types map covers every required column', () {
      for (final col in SyncColumns.required) {
        expect(SyncColumns.types.containsKey(col), isTrue,
            reason: '$col missing from types map');
      }
    });

    test('types for createdAt/updatedAt are INTEGER NOT NULL', () {
      expect(SyncColumns.types[SyncColumns.createdAt], 'INTEGER NOT NULL');
      expect(SyncColumns.types[SyncColumns.updatedAt], 'INTEGER NOT NULL');
    });

    test('deleted_at type is nullable INTEGER', () {
      expect(SyncColumns.types[SyncColumns.deletedAt], 'INTEGER');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/schema/sync_columns_test.dart
```
Expected: compile error.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/schema/sync_columns.dart`

```dart
/// Canonical column names every user-defined synced table must include.
///
/// Users own their local schemas (adapters do not auto-create tables);
/// `LocalDatabaseAdapter.validateSchema` is called at init to confirm
/// each column exists. Adapters for NoSQL stores (Hive, ObjectBox)
/// translate these to their native shape but must honor the names.
class SyncColumns {
  SyncColumns._();

  /// Primary key — `TEXT NOT NULL PRIMARY KEY`, UUIDv4.
  static const id = 'id';

  /// Wall-clock creation time, `INTEGER NOT NULL` millisSinceEpoch UTC.
  static const createdAt = 'created_at';

  /// Wall-clock last-update time, `INTEGER NOT NULL` millisSinceEpoch UTC.
  static const updatedAt = 'updated_at';

  /// Soft-delete timestamp, `INTEGER` nullable; millisSinceEpoch UTC.
  static const deletedAt = 'deleted_at';

  /// Acknowledged-by-server flag, `INTEGER NOT NULL DEFAULT 0`.
  static const isSynced = 'is_synced';

  /// Lifecycle status name, `TEXT NOT NULL DEFAULT 'pending'`.
  static const syncStatus = 'sync_status';

  /// Every column name a synced table must include, in canonical order.
  static const required = <String>[
    id,
    createdAt,
    updatedAt,
    deletedAt,
    isSynced,
    syncStatus,
  ];

  /// Non-prescriptive reference SQL types for SQL-shaped adapters.
  /// NoSQL adapters translate to native shapes.
  static const Map<String, String> types = {
    id: 'TEXT NOT NULL PRIMARY KEY',
    createdAt: 'INTEGER NOT NULL',
    updatedAt: 'INTEGER NOT NULL',
    deletedAt: 'INTEGER',
    isSynced: 'INTEGER NOT NULL DEFAULT 0',
    syncStatus: "TEXT NOT NULL DEFAULT 'pending'",
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/schema/sync_columns_test.dart
dart analyze
```
Expected: 5 tests pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/schema/sync_columns.dart \
        packages/flutter_universal_sync_core/test/schema/sync_columns_test.dart
git commit -m "feat(core): add SyncColumns schema contract"
```

---

## Task 7: `SyncException` hierarchy

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/errors/sync_errors.dart`
- Test: `packages/flutter_universal_sync_core/test/errors/sync_errors_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/errors/sync_errors_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/errors/sync_errors.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaValidationException', () {
    test('formats message with table name and missing columns', () {
      final ex = SchemaValidationException(
        table: 'products',
        missingColumns: ['deleted_at', 'sync_status'],
      );
      expect(ex.message,
          equals('Table products is missing sync columns: '
              'deleted_at, sync_status'));
      expect(ex.toString(), equals('SchemaValidationException: ${ex.message}'));
    });

    test('is a SyncException', () {
      expect(
        SchemaValidationException(table: 't', missingColumns: const ['x']),
        isA<SyncException>(),
      );
    });
  });

  group('SyncPushException', () {
    test('wraps the underlying cause', () {
      final cause = StateError('500');
      final ex = SyncPushException(queueEntryId: 'q1', cause: cause);
      expect(ex.queueEntryId, 'q1');
      expect(ex.cause, same(cause));
      expect(ex.message, contains('q1'));
      expect(ex.message, contains('500'));
    });
  });

  group('SyncPullException', () {
    test('includes table name in message', () {
      final ex = SyncPullException(table: 'orders', cause: 'timeout');
      expect(ex.message, contains('orders'));
      expect(ex.message, contains('timeout'));
    });
  });

  group('ConflictResolutionException', () {
    test('includes entity id in message', () {
      final ex = ConflictResolutionException(
        entityId: 'e42',
        cause: Exception('resolver bug'),
      );
      expect(ex.entityId, 'e42');
      expect(ex.message, contains('e42'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/errors/sync_errors_test.dart
```
Expected: compile error.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/errors/sync_errors.dart`

```dart
/// Base type for every exception thrown by the flutter_universal_sync family.
sealed class SyncException implements Exception {
  /// Human-readable message.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown by `LocalDatabaseAdapter.validateSchema` when a user-declared
/// table is missing one or more required sync columns.
class SchemaValidationException extends SyncException {
  /// Creates a schema validation exception.
  SchemaValidationException({
    required this.table,
    required this.missingColumns,
  });

  /// Name of the offending table.
  final String table;

  /// Columns that were absent from the table's schema.
  final List<String> missingColumns;

  @override
  String get message =>
      'Table $table is missing sync columns: ${missingColumns.join(', ')}';
}

/// Thrown by `RemoteSyncAdapter.pushChange` implementations when a single
/// queue entry fails to push. Plan 1's stop-on-first-failure semantics
/// mean this halts the current sync batch; the entry remains in the queue.
class SyncPushException extends SyncException {
  /// Creates a push exception.
  SyncPushException({required this.queueEntryId, required this.cause});

  /// The queue entry that failed.
  final String queueEntryId;

  /// The underlying failure (network error, HTTP code, etc.).
  final Object cause;

  @override
  String get message =>
      'Failed to push queue entry $queueEntryId: $cause';
}

/// Thrown by `RemoteSyncAdapter.pullChanges` implementations when fetching
/// remote changes for a table fails.
class SyncPullException extends SyncException {
  /// Creates a pull exception.
  SyncPullException({required this.table, required this.cause});

  /// Table whose pull failed.
  final String table;

  /// The underlying failure.
  final Object cause;

  @override
  String get message => 'Failed to pull changes for $table: $cause';
}

/// Thrown when a user-provided `ConflictResolver.resolve` call itself
/// throws — distinguishes resolver bugs from sync-layer failures.
class ConflictResolutionException extends SyncException {
  /// Creates a conflict resolution exception.
  ConflictResolutionException({required this.entityId, required this.cause});

  /// Id of the row whose conflict resolution failed.
  final String entityId;

  /// The underlying failure.
  final Object cause;

  @override
  String get message =>
      'Conflict resolver failed for entity $entityId: $cause';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/errors/sync_errors_test.dart
dart analyze
```
Expected: 5 tests pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/errors/sync_errors.dart \
        packages/flutter_universal_sync_core/test/errors/sync_errors_test.dart
git commit -m "feat(core): add SyncException hierarchy"
```

---

## Task 8: `IdGenerator` + `UuidV4Generator`

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/id/id_generator.dart`
- Test: `packages/flutter_universal_sync_core/test/id/id_generator_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/id/id_generator_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/id/id_generator.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('UuidV4Generator', () {
    test('produces a valid RFC 4122 v4 UUID', () {
      final id = UuidV4Generator().nextId();
      expect(id, matches(_uuidRegex),
          reason: '$id is not a valid v4 UUID');
    });

    test('two consecutive ids are different', () {
      final gen = UuidV4Generator();
      expect(gen.nextId(), isNot(equals(gen.nextId())));
    });

    test('accepts an injected Uuid for deterministic tests', () {
      final fixed = const Uuid().v5(Uuid.NAMESPACE_URL, 'fixed-seed');
      final gen = UuidV4Generator(uuid: _StubUuid(fixed));
      expect(gen.nextId(), fixed);
    });
  });
}

class _StubUuid extends Uuid {
  _StubUuid(this._value);
  final String _value;
  @override
  String v4({V4Options? options}) => _value;
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/id/id_generator_test.dart
```
Expected: compile error.

- [ ] **Step 3: Write the implementation**

Path: `lib/src/id/id_generator.dart`

```dart
import 'package:uuid/uuid.dart';

/// Generator for stable, unique row identifiers.
///
/// The default implementation ([UuidV4Generator]) produces RFC 4122 v4 UUIDs.
/// Tests can inject a deterministic generator to make assertions on ids.
abstract class IdGenerator {
  /// Returns a new unique identifier.
  String nextId();
}

/// Produces UUIDv4 identifiers via `package:uuid`.
class UuidV4Generator implements IdGenerator {
  /// Creates a generator. Inject [uuid] in tests for deterministic output.
  UuidV4Generator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String nextId() => _uuid.v4();
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/id/id_generator_test.dart
dart analyze
```
Expected: 3 tests pass; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/id/id_generator.dart \
        packages/flutter_universal_sync_core/test/id/id_generator_test.dart
git commit -m "feat(core): add IdGenerator and UuidV4Generator"
```

---

## Task 9: `ConflictResolver` + `LastWriteWinsResolver`

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/conflict/conflict_resolver.dart`
- Create: `packages/flutter_universal_sync_core/lib/src/conflict/last_write_wins_resolver.dart`
- Test: `packages/flutter_universal_sync_core/test/conflict/last_write_wins_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

Path: `test/conflict/last_write_wins_resolver_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/conflict/last_write_wins_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('LastWriteWinsResolver', () {
    final earlier = DateTime.utc(2026, 4, 24, 10, 0, 0);
    final later = DateTime.utc(2026, 4, 24, 11, 0, 0);

    test('returns the row with the later DateTime updated_at', () {
      final local = {'id': 'a', 'updated_at': later, 'name': 'local'};
      final remote = {'id': 'a', 'updated_at': earlier, 'name': 'remote'};
      expect(LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('remote wins when its updated_at is later', () {
      final local = {'id': 'a', 'updated_at': earlier};
      final remote = {'id': 'a', 'updated_at': later};
      expect(LastWriteWinsResolver().resolve(local, remote), remote);
    });

    test('on exact tie, remote wins (deterministic tiebreak)', () {
      final local = {'id': 'a', 'updated_at': later, 'name': 'local'};
      final remote = {'id': 'a', 'updated_at': later, 'name': 'remote'};
      expect(LastWriteWinsResolver().resolve(local, remote), remote);
    });

    test('accepts ISO-8601 strings for updated_at', () {
      final local = {'id': 'a', 'updated_at': later.toIso8601String()};
      final remote = {'id': 'a', 'updated_at': earlier.toIso8601String()};
      expect(LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('accepts millisSinceEpoch ints for updated_at', () {
      final local = {'id': 'a', 'updated_at': later.millisecondsSinceEpoch};
      final remote = {'id': 'a', 'updated_at': earlier.millisecondsSinceEpoch};
      expect(LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('throws ArgumentError if updated_at is missing', () {
      expect(
        () => LastWriteWinsResolver().resolve({'id': 'a'}, {'id': 'a'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for unsupported updated_at type', () {
      expect(
        () => LastWriteWinsResolver().resolve(
          {'id': 'a', 'updated_at': <String, dynamic>{}},
          {'id': 'a', 'updated_at': <String, dynamic>{}},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
dart test test/conflict/last_write_wins_resolver_test.dart
```
Expected: compile error.

- [ ] **Step 3: Write the `ConflictResolver` interface**

Path: `lib/src/conflict/conflict_resolver.dart`

```dart
/// Strategy for reconciling two concurrent row versions for the same id.
///
/// Invocation is the sync engine's responsibility (Plan 2); this contract
/// is pure — given [local] and [remote] maps, return the merged map.
/// If the strategy is deterministic, [resolve] must not have side effects.
abstract class ConflictResolver {
  /// Returns the merged row that should replace both sides.
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  );
}
```

- [ ] **Step 4: Write the `LastWriteWinsResolver`**

Path: `lib/src/conflict/last_write_wins_resolver.dart`

```dart
import 'conflict_resolver.dart';

/// Chooses whichever row has the later `updated_at`. On an exact tie,
/// returns [remote] so the result is deterministic even with clock skew.
///
/// Accepts [DateTime], ISO-8601 strings, or `int` millisSinceEpoch for the
/// `updated_at` field. Throws [ArgumentError] if the field is missing or
/// typed unexpectedly — conflict data without timestamps is a bug upstream.
class LastWriteWinsResolver implements ConflictResolver {
  /// Creates the resolver.
  const LastWriteWinsResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final l = _toUtc(local['updated_at'], side: 'local');
    final r = _toUtc(remote['updated_at'], side: 'remote');
    return l.isAfter(r) ? local : remote;
  }

  DateTime _toUtc(Object? value, {required String side}) {
    if (value == null) {
      throw ArgumentError.value(
        value,
        '$side.updated_at',
        'updated_at is required for conflict resolution',
      );
    }
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) return DateTime.parse(value).toUtc();
    throw ArgumentError.value(
      value,
      '$side.updated_at',
      'Unsupported type for updated_at (got ${value.runtimeType})',
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
dart test test/conflict/last_write_wins_resolver_test.dart
dart analyze
```
Expected: 7 tests pass; no analyzer issues.

- [ ] **Step 6: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/conflict/conflict_resolver.dart \
        packages/flutter_universal_sync_core/lib/src/conflict/last_write_wins_resolver.dart \
        packages/flutter_universal_sync_core/test/conflict/last_write_wins_resolver_test.dart
git commit -m "feat(core): add ConflictResolver interface and LastWriteWinsResolver"
```

---

## Task 10: `ServerPriorityResolver` + `ClientPriorityResolver`

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/conflict/server_priority_resolver.dart`
- Create: `packages/flutter_universal_sync_core/lib/src/conflict/client_priority_resolver.dart`
- Test: `packages/flutter_universal_sync_core/test/conflict/server_priority_resolver_test.dart`
- Test: `packages/flutter_universal_sync_core/test/conflict/client_priority_resolver_test.dart`

- [ ] **Step 1: Write the failing tests**

Path: `test/conflict/server_priority_resolver_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/conflict/server_priority_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('ServerPriorityResolver', () {
    test('always returns the remote row', () {
      final local = {'id': 'a', 'name': 'local'};
      final remote = {'id': 'a', 'name': 'remote'};
      expect(const ServerPriorityResolver().resolve(local, remote), remote);
    });

    test('returns the remote row even when local has more fields', () {
      expect(
        const ServerPriorityResolver().resolve(
          {'id': 'a', 'name': 'local', 'extra': 1},
          {'id': 'a', 'name': 'remote'},
        ),
        {'id': 'a', 'name': 'remote'},
      );
    });
  });
}
```

Path: `test/conflict/client_priority_resolver_test.dart`

```dart
import 'package:flutter_universal_sync_core/src/conflict/client_priority_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('ClientPriorityResolver', () {
    test('always returns the local row', () {
      final local = {'id': 'a', 'name': 'local'};
      final remote = {'id': 'a', 'name': 'remote'};
      expect(const ClientPriorityResolver().resolve(local, remote), local);
    });

    test('returns the local row even when remote has more fields', () {
      expect(
        const ClientPriorityResolver().resolve(
          {'id': 'a', 'name': 'local'},
          {'id': 'a', 'name': 'remote', 'extra': 1},
        ),
        {'id': 'a', 'name': 'local'},
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
dart test test/conflict/server_priority_resolver_test.dart test/conflict/client_priority_resolver_test.dart
```
Expected: compile errors — both files don't exist.

- [ ] **Step 3: Write `ServerPriorityResolver`**

Path: `lib/src/conflict/server_priority_resolver.dart`

```dart
import 'conflict_resolver.dart';

/// Always picks the remote row; discards local edits on conflict.
class ServerPriorityResolver implements ConflictResolver {
  /// Creates the resolver.
  const ServerPriorityResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) =>
      remote;
}
```

- [ ] **Step 4: Write `ClientPriorityResolver`**

Path: `lib/src/conflict/client_priority_resolver.dart`

```dart
import 'conflict_resolver.dart';

/// Always picks the local row; discards remote edits on conflict.
class ClientPriorityResolver implements ConflictResolver {
  /// Creates the resolver.
  const ClientPriorityResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) =>
      local;
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
dart test test/conflict/server_priority_resolver_test.dart test/conflict/client_priority_resolver_test.dart
dart analyze
```
Expected: 4 tests pass; no analyzer issues.

- [ ] **Step 6: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/conflict/server_priority_resolver.dart \
        packages/flutter_universal_sync_core/lib/src/conflict/client_priority_resolver.dart \
        packages/flutter_universal_sync_core/test/conflict/server_priority_resolver_test.dart \
        packages/flutter_universal_sync_core/test/conflict/client_priority_resolver_test.dart
git commit -m "feat(core): add ServerPriorityResolver and ClientPriorityResolver"
```

---

## Task 11: `LocalDatabaseAdapter` abstract interface

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart`

No dedicated test file — the interface is exercised by the in-memory stub (Task 14) and the contract suite (Tasks 15–18). A compile-time check via `dart analyze` is enough here.

- [ ] **Step 1: Write the interface**

Path: `lib/src/adapters/local_database_adapter.dart`

```dart
import '../entities/sync_queue_entry.dart';

/// Port every local database (sqflite, drift, hive, objectbox) implements.
///
/// The interface is Map-based for DB agnosticism — the repository layer
/// (Plan 13) is responsible for mapping to/from typed entities.
///
/// **Atomicity.** [transaction] must be a real atomic transaction: the
/// domain-row write + [enqueueSync] enqueueing of the corresponding queue
/// entry must either both succeed or both fail. Partial writes across
/// crashes cause silent sync loss.
///
/// **Soft delete.** [delete] never hard-removes the row; it sets
/// `deleted_at` to `DateTime.now().toUtc().millisecondsSinceEpoch`. Hard
/// removal is the sync engine's concern (future — not Plan 1).
///
/// **Schema ownership.** Users own their table definitions. Adapters do
/// **not** create tables. [validateSchema] is called at init to confirm
/// every required sync column is present, throwing
/// [SchemaValidationException] on a mismatch.
abstract class LocalDatabaseAdapter {
  /// Opens the underlying database. Must be called exactly once.
  Future<void> init();

  /// Releases underlying resources. Safe to call multiple times.
  Future<void> close();

  /// Inserts a row. Throws [StateError] if a row with the same id exists.
  /// Caller supplies all sync metadata fields; the adapter does not
  /// populate them.
  Future<void> insert(String table, Map<String, dynamic> data);

  /// Patches the row with matching id — keys in [data] are written; keys
  /// absent from [data] are unchanged. Caller must include `updated_at`
  /// in [data]. Throws [StateError] if the row does not exist.
  Future<void> update(String table, String id, Map<String, dynamic> data);

  /// Soft-deletes the row: sets `deleted_at` to the current UTC time.
  /// Throws [StateError] if the row does not exist.
  Future<void> delete(String table, String id);

  /// Returns the row with the given id, or `null` if it does not exist.
  /// Soft-deleted rows are returned (inspect `deleted_at` to detect).
  Future<Map<String, dynamic>?> getById(String table, String id);

  /// Returns all rows from [table]. Default behaviour filters out
  /// soft-deleted rows (`deleted_at IS NULL`). Pass `includeDeleted: true`
  /// for a full listing (e.g. for the sync engine's pull-reconciliation).
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  });

  /// Appends a queue entry. Should only be invoked inside [transaction]
  /// alongside the corresponding domain-table mutation.
  Future<void> enqueueSync(SyncQueueEntry entry);

  /// Returns entries with `synced = false` in insertion order, up to [limit].
  /// `null` limit returns every pending entry.
  Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit});

  /// Marks the given queue entry as successfully synced.
  Future<void> markSynced(String queueEntryId);

  /// Records a failed push attempt: stores [error] on the entry's
  /// `last_error`. Plan 1 does not increment `retry_count`; Plan 2 will.
  Future<void> recordSyncFailure(String queueEntryId, String error);

  /// Runs [action] inside a single atomic transaction. If [action] throws,
  /// every write performed during the callback is rolled back.
  Future<T> transaction<T>(Future<T> Function() action);

  /// Verifies every table in [tables] includes the required sync columns.
  /// Throws [SchemaValidationException] listing missing columns on mismatch.
  Future<void> validateSchema(List<String> tables);
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart analyze
```
Expected: no issues found.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/adapters/local_database_adapter.dart
git commit -m "feat(core): add LocalDatabaseAdapter interface"
```

---

## Task 12: `RemoteSyncAdapter` abstract interface

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/adapters/remote_sync_adapter.dart`

Same approach as Task 11 — no standalone test; `dart analyze` is the gate.

- [ ] **Step 1: Write the interface**

Path: `lib/src/adapters/remote_sync_adapter.dart`

```dart
import '../entities/sync_queue_entry.dart';

/// Port every remote backend (firebase, supabase, appwrite, graphql, rest)
/// implements.
///
/// Per-op semantics: the sync engine calls [pushChange] once per queue
/// entry in FIFO order. Plan 1's stop-on-first-failure semantics mean a
/// thrown [SyncPushException] halts the current batch; the entry stays
/// queued and will be retried on the next sync cycle.
abstract class RemoteSyncAdapter {
  /// Pushes one queue entry to the backend. Throws [SyncPushException]
  /// (wrapping the cause) on any failure — network, HTTP code, validation,
  /// etc. Success returns normally; the engine then calls `markSynced`
  /// on the local adapter.
  Future<void> pushChange(SyncQueueEntry entry);

  /// Fetches rows for [table] updated after [since]. Passing `null` returns
  /// every row. Implementations should filter with
  /// `updated_at > since OR deleted_at > since` so soft-deletes propagate.
  /// Pagination is adapter-internal. Throws [SyncPullException] on failure.
  Future<List<Map<String, dynamic>>> pullChanges(String table, DateTime? since);
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart analyze
```
Expected: no issues found.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/adapters/remote_sync_adapter.dart
git commit -m "feat(core): add RemoteSyncAdapter interface"
```

---

## Task 13: Production barrel export

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/flutter_universal_sync_core.dart`
- Test: `packages/flutter_universal_sync_core/test/barrel_test.dart`

- [ ] **Step 1: Write the barrel smoke test**

Path: `test/barrel_test.dart`

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:test/test.dart';

void main() {
  group('flutter_universal_sync_core barrel', () {
    test('exports every public type', () {
      // Compile-time check: every symbol below must be importable via
      // the barrel alone. If a symbol is missing, this file won't compile.
      expect(SyncOperation.insert, isNotNull);
      expect(SyncStatus.pending, isNotNull);
      expect(SyncColumns.id, 'id');
      expect(UuidV4Generator().nextId(), isNotEmpty);
      expect(const LastWriteWinsResolver(), isA<ConflictResolver>());
      expect(const ServerPriorityResolver(), isA<ConflictResolver>());
      expect(const ClientPriorityResolver(), isA<ConflictResolver>());

      // Type-reference checks — force the identifiers to be linked.
      const ignoreLocal = <Type>[
        SyncEntity,
        SyncQueueEntry,
        LocalDatabaseAdapter,
        RemoteSyncAdapter,
        SyncException,
        SchemaValidationException,
        SyncPushException,
        SyncPullException,
        ConflictResolutionException,
        IdGenerator,
      ];
      expect(ignoreLocal, hasLength(10));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/barrel_test.dart
```
Expected: compile error — `flutter_universal_sync_core.dart` doesn't exist yet.

- [ ] **Step 3: Write the barrel**

Path: `lib/flutter_universal_sync_core.dart`

```dart
/// Core contracts for the flutter_universal_sync offline-first package family.
///
/// See `README.md` and the spec in the monorepo's `docs/superpowers/specs/`
/// for architectural context.
library;

export 'src/adapters/local_database_adapter.dart';
export 'src/adapters/remote_sync_adapter.dart';
export 'src/conflict/client_priority_resolver.dart';
export 'src/conflict/conflict_resolver.dart';
export 'src/conflict/last_write_wins_resolver.dart';
export 'src/conflict/server_priority_resolver.dart';
export 'src/entities/sync_entity.dart';
export 'src/entities/sync_operation.dart';
export 'src/entities/sync_queue_entry.dart';
export 'src/entities/sync_status.dart';
export 'src/errors/sync_errors.dart';
export 'src/id/id_generator.dart';
export 'src/schema/sync_columns.dart';
```

- [ ] **Step 4: Run test to verify it passes**

```bash
dart test test/barrel_test.dart
dart analyze
```
Expected: test passes; no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/flutter_universal_sync_core.dart \
        packages/flutter_universal_sync_core/test/barrel_test.dart
git commit -m "feat(core): add production barrel export"
```

---

## Task 14: In-memory stub adapter

**Files:**
- Create: `packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart`

Purely a test helper — lives under `test/`, never published. Its job is to give us a working `LocalDatabaseAdapter` implementation that Tasks 15–18 can run the contract suite against. Not itself tested here (the contract suite *is* its test).

- [ ] **Step 1: Write the stub**

Path: `test/support/in_memory_adapter.dart`

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// An in-memory [LocalDatabaseAdapter] used to exercise the contract suite.
///
/// Storage shape:
///   _tables:  tableName -> rowId -> row map
///   _schemas: tableName -> set of column names (registered via
///             [registerTable] in tests before `validateSchema` is called)
///   _queue:   insertion-ordered list of queue entries
class InMemoryAdapter implements LocalDatabaseAdapter {
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  final Map<String, Set<String>> _schemas = {};
  final List<SyncQueueEntry> _queue = [];

  /// Registers [columns] as the schema for [table]. Tests call this
  /// before [validateSchema] to simulate user-declared tables.
  void registerTable(String table, Iterable<String> columns) {
    _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    _schemas[table] = columns.toSet();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final rows = _tables.putIfAbsent(table, () => <String, Map<String, dynamic>>{});
    final id = data[SyncColumns.id] as String;
    if (rows.containsKey(id)) {
      throw StateError('Row $id already exists in $table');
    }
    rows[id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    final rows = _tables[table];
    if (rows == null || !rows.containsKey(id)) {
      throw StateError('Row $id not found in $table');
    }
    rows[id]!.addAll(data);
  }

  @override
  Future<void> delete(String table, String id) async {
    final rows = _tables[table];
    if (rows == null || !rows.containsKey(id)) {
      throw StateError('Row $id not found in $table');
    }
    rows[id]![SyncColumns.deletedAt] =
        DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  @override
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final row = _tables[table]?[id];
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    bool includeDeleted = false,
  }) async {
    final rows = _tables[table]?.values.toList() ?? <Map<String, dynamic>>[];
    final iter = includeDeleted
        ? rows
        : rows.where((r) => r[SyncColumns.deletedAt] == null);
    return iter.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> enqueueSync(SyncQueueEntry entry) async {
    _queue.add(entry);
  }

  @override
  Future<List<SyncQueueEntry>> pendingSyncEntries({int? limit}) async {
    final pending = _queue.where((e) => !e.synced).toList();
    if (limit == null || limit >= pending.length) return pending;
    return pending.sublist(0, limit);
  }

  @override
  Future<void> markSynced(String queueEntryId) async {
    final i = _queue.indexWhere((e) => e.id == queueEntryId);
    if (i < 0) throw StateError('Queue entry $queueEntryId not found');
    _queue[i] = _queue[i].copyWith(synced: true);
  }

  @override
  Future<void> recordSyncFailure(String queueEntryId, String error) async {
    final i = _queue.indexWhere((e) => e.id == queueEntryId);
    if (i < 0) throw StateError('Queue entry $queueEntryId not found');
    _queue[i] = _queue[i].copyWith(lastError: error);
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    // Snapshot for rollback on throw.
    final tablesSnapshot = <String, Map<String, Map<String, dynamic>>>{
      for (final entry in _tables.entries)
        entry.key: {
          for (final row in entry.value.entries)
            row.key: Map<String, dynamic>.from(row.value),
        },
    };
    final queueSnapshot = List<SyncQueueEntry>.from(_queue);
    try {
      return await action();
    } catch (_) {
      _tables
        ..clear()
        ..addAll(tablesSnapshot);
      _queue
        ..clear()
        ..addAll(queueSnapshot);
      rethrow;
    }
  }

  @override
  Future<void> validateSchema(List<String> tables) async {
    for (final table in tables) {
      final declared = _schemas[table] ?? const <String>{};
      final missing =
          SyncColumns.required.where((c) => !declared.contains(c)).toList();
      if (missing.isNotEmpty) {
        throw SchemaValidationException(
          table: table,
          missingColumns: missing,
        );
      }
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart analyze
```
Expected: no issues found.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/test/support/in_memory_adapter.dart
git commit -m "test(core): add in-memory LocalDatabaseAdapter stub"
```

---

## Task 15: Contract suite — domain CRUD

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart` (initial version; Tasks 16–18 append)
- Create: `packages/flutter_universal_sync_core/test/contract_suite_test.dart` (initial version; Tasks 16–18 don't add new files here)

- [ ] **Step 1: Write the contract suite entry point + domain CRUD tests**

Path: `lib/src/testing/local_database_adapter_contract.dart`

```dart
import 'package:test/test.dart';

import '../adapters/local_database_adapter.dart';
import '../entities/sync_operation.dart';
import '../entities/sync_queue_entry.dart';
import '../errors/sync_errors.dart';
import '../schema/sync_columns.dart';

/// Runs the `LocalDatabaseAdapter` contract suite against [factory].
///
/// Every local-adapter package (sqflite, drift, hive, objectbox) must call
/// this in its test file with a factory that produces a fresh adapter
/// instance per test. [createTestTable] is invoked once per test to register
/// the `things` table with the required sync columns on the newly-created
/// adapter (implementations vary: in-memory registers a column set; sqflite
/// runs a CREATE TABLE; etc.).
void runLocalDatabaseAdapterContract({
  required LocalDatabaseAdapter Function() factory,
  required Future<void> Function(LocalDatabaseAdapter) createTestTable,
  required String adapterName,
}) {
  group('$adapterName — LocalDatabaseAdapter contract', () {
    late LocalDatabaseAdapter adapter;

    setUp(() async {
      adapter = factory();
      await adapter.init();
      await createTestTable(adapter);
    });

    tearDown(() async {
      await adapter.close();
    });

    Map<String, dynamic> thingRow({
      String id = 't1',
      String? name,
      int? updatedAt,
      int? deletedAt,
    }) =>
        {
          SyncColumns.id: id,
          SyncColumns.createdAt: 1_700_000_000_000,
          SyncColumns.updatedAt: updatedAt ?? 1_700_000_000_000,
          SyncColumns.deletedAt: deletedAt,
          SyncColumns.isSynced: 0,
          SyncColumns.syncStatus: 'pending',
          if (name != null) 'name': name,
        };

    group('domain CRUD', () {
      test('insert then getById round-trips the row', () async {
        await adapter.insert('things', thingRow(name: 'apple'));
        final loaded = await adapter.getById('things', 't1');
        expect(loaded, isNotNull);
        expect(loaded![SyncColumns.id], 't1');
        expect(loaded['name'], 'apple');
      });

      test('getById returns null for unknown id', () async {
        expect(await adapter.getById('things', 'nope'), isNull);
      });

      test('update applies patch semantics', () async {
        await adapter.insert('things', thingRow(name: 'apple'));
        await adapter.update('things', 't1', {
          'name': 'banana',
          SyncColumns.updatedAt: 1_700_000_005_000,
        });
        final row = await adapter.getById('things', 't1');
        expect(row!['name'], 'banana');
        // createdAt NOT passed to update — must be unchanged
        expect(row[SyncColumns.createdAt], 1_700_000_000_000);
        expect(row[SyncColumns.updatedAt], 1_700_000_005_000);
      });

      test('update on missing row throws StateError', () async {
        expect(
          () => adapter.update('things', 'nope', {'name': 'x'}),
          throwsA(isA<StateError>()),
        );
      });

      test('delete sets deleted_at (soft delete)', () async {
        await adapter.insert('things', thingRow(name: 'apple'));
        await adapter.delete('things', 't1');
        final row = await adapter.getById('things', 't1');
        expect(row, isNotNull,
            reason: 'soft-deleted rows must not be hard-removed');
        expect(row![SyncColumns.deletedAt], isNotNull);
      });

      test('delete on missing row throws StateError', () async {
        expect(
          () => adapter.delete('things', 'nope'),
          throwsA(isA<StateError>()),
        );
      });

      test('getAll excludes soft-deleted rows by default', () async {
        await adapter.insert('things', thingRow(id: 'a', name: 'apple'));
        await adapter.insert('things', thingRow(id: 'b', name: 'banana'));
        await adapter.delete('things', 'a');
        final rows = await adapter.getAll('things');
        expect(rows.map((r) => r[SyncColumns.id]), ['b']);
      });

      test('getAll with includeDeleted returns every row', () async {
        await adapter.insert('things', thingRow(id: 'a', name: 'apple'));
        await adapter.insert('things', thingRow(id: 'b', name: 'banana'));
        await adapter.delete('things', 'a');
        final rows = await adapter.getAll('things', includeDeleted: true);
        expect(rows.map((r) => r[SyncColumns.id]).toSet(), {'a', 'b'});
      });
    });
  });
}
```

- [ ] **Step 2: Write the test that runs the suite against the stub**

Path: `test/contract_suite_test.dart`

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/src/testing/local_database_adapter_contract.dart';

import 'support/in_memory_adapter.dart';

void main() {
  runLocalDatabaseAdapterContract(
    factory: InMemoryAdapter.new,
    adapterName: 'InMemoryAdapter',
    createTestTable: (a) async {
      (a as InMemoryAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
  );
}
```

- [ ] **Step 3: Run the suite**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart
dart analyze
```
Expected: 8 tests pass under the `InMemoryAdapter — LocalDatabaseAdapter contract > domain CRUD` group; no analyzer issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/contract_suite_test.dart
git commit -m "test(core): contract suite — domain CRUD"
```

---

## Task 16: Contract suite — queue operations

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart` — append queue-ops group

- [ ] **Step 1: Append the queue-ops group**

Add the following inside the existing `group('$adapterName — LocalDatabaseAdapter contract', () { ... })`, immediately after the closing brace of `group('domain CRUD', ...)`:

```dart
    group('queue operations', () {
      SyncQueueEntry entry({
        String id = 'q1',
        bool synced = false,
        String? lastError,
      }) =>
          SyncQueueEntry(
            id: id,
            table: 'things',
            entityId: 't1',
            operation: SyncOperation.insert,
            payload: thingRow(name: 'apple'),
            createdAt: DateTime.utc(2026, 4, 24),
            synced: synced,
            lastError: lastError,
          );

      test('enqueue then pendingSyncEntries returns it', () async {
        await adapter.enqueueSync(entry());
        final pending = await adapter.pendingSyncEntries();
        expect(pending.map((e) => e.id), ['q1']);
      });

      test('pendingSyncEntries preserves insertion order', () async {
        await adapter.enqueueSync(entry(id: 'q1'));
        await adapter.enqueueSync(entry(id: 'q2'));
        await adapter.enqueueSync(entry(id: 'q3'));
        expect(
          (await adapter.pendingSyncEntries()).map((e) => e.id),
          ['q1', 'q2', 'q3'],
        );
      });

      test('pendingSyncEntries honors limit', () async {
        await adapter.enqueueSync(entry(id: 'q1'));
        await adapter.enqueueSync(entry(id: 'q2'));
        await adapter.enqueueSync(entry(id: 'q3'));
        expect(
          (await adapter.pendingSyncEntries(limit: 2)).map((e) => e.id),
          ['q1', 'q2'],
        );
      });

      test('pendingSyncEntries excludes synced entries', () async {
        await adapter.enqueueSync(entry(id: 'q1'));
        await adapter.enqueueSync(entry(id: 'q2'));
        await adapter.markSynced('q1');
        expect(
          (await adapter.pendingSyncEntries()).map((e) => e.id),
          ['q2'],
        );
      });

      test('markSynced on unknown entry throws StateError', () async {
        expect(
          () => adapter.markSynced('nope'),
          throwsA(isA<StateError>()),
        );
      });

      test('recordSyncFailure updates lastError', () async {
        await adapter.enqueueSync(entry(id: 'q1'));
        await adapter.recordSyncFailure('q1', 'boom');
        final pending = await adapter.pendingSyncEntries();
        expect(pending.single.lastError, 'boom');
        expect(pending.single.synced, isFalse);
      });

      test('recordSyncFailure on unknown entry throws StateError', () async {
        expect(
          () => adapter.recordSyncFailure('nope', 'err'),
          throwsA(isA<StateError>()),
        );
      });
    });
```

- [ ] **Step 2: Run the suite**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart
dart analyze
```
Expected: 15 tests pass in total (8 CRUD + 7 queue); no analyzer issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart
git commit -m "test(core): contract suite — queue operations"
```

---

## Task 17: Contract suite — transaction atomicity

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart` — append transaction group

- [ ] **Step 1: Append the transaction group**

Add the following inside the existing `group('$adapterName — LocalDatabaseAdapter contract', () { ... })`, after the `queue operations` group:

```dart
    group('transaction atomicity', () {
      test('successful transaction commits both domain + queue writes',
          () async {
        await adapter.transaction(() async {
          await adapter.insert('things', thingRow(name: 'apple'));
          await adapter.enqueueSync(SyncQueueEntry(
            id: 'q1',
            table: 'things',
            entityId: 't1',
            operation: SyncOperation.insert,
            payload: thingRow(name: 'apple'),
            createdAt: DateTime.utc(2026, 4, 24),
          ));
        });
        expect(await adapter.getById('things', 't1'), isNotNull);
        expect((await adapter.pendingSyncEntries()).map((e) => e.id), ['q1']);
      });

      test('throwing transaction rolls back both writes', () async {
        try {
          await adapter.transaction(() async {
            await adapter.insert('things', thingRow(name: 'apple'));
            await adapter.enqueueSync(SyncQueueEntry(
              id: 'q1',
              table: 'things',
              entityId: 't1',
              operation: SyncOperation.insert,
              payload: thingRow(name: 'apple'),
              createdAt: DateTime.utc(2026, 4, 24),
            ));
            throw StateError('rollback please');
          });
          fail('transaction should have thrown');
        } on StateError catch (e) {
          expect(e.message, 'rollback please');
        }
        expect(await adapter.getById('things', 't1'), isNull,
            reason: 'domain write must roll back');
        expect(await adapter.pendingSyncEntries(), isEmpty,
            reason: 'queue write must roll back');
      });

      test('exception from nested operation still rolls back everything',
          () async {
        // Row exists before the transaction; attempting to re-insert throws.
        await adapter.insert('things', thingRow(id: 'existing', name: 'old'));
        try {
          await adapter.transaction(() async {
            await adapter.update('things', 'existing', {
              'name': 'new',
              SyncColumns.updatedAt: 1_700_000_005_000,
            });
            // This second insert fails (duplicate id).
            await adapter.insert('things', thingRow(id: 'existing'));
          });
          fail('should have thrown');
        } on StateError catch (_) {/* expected */}
        final row = await adapter.getById('things', 'existing');
        expect(row!['name'], 'old',
            reason: 'earlier update must be rolled back too');
      });
    });
```

- [ ] **Step 2: Run the suite**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart
dart analyze
```
Expected: 18 tests pass in total (8 + 7 + 3); no analyzer issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart
git commit -m "test(core): contract suite — transaction atomicity"
```

---

## Task 18: Contract suite — schema validation

**Files:**
- Modify: `packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart` — append schema validation group

- [ ] **Step 1: Extend the contract suite signature with `createBrokenTable`**

The "broken" table used in the missing-columns test is set up differently per adapter (in-memory: `registerTable`; sqflite: a partial CREATE TABLE; drift: a pre-built DAO). To keep the shared suite adapter-agnostic, accept a second setup callback.

In `lib/src/testing/local_database_adapter_contract.dart`, update the function signature:

```dart
void runLocalDatabaseAdapterContract({
  required LocalDatabaseAdapter Function() factory,
  required Future<void> Function(LocalDatabaseAdapter) createTestTable,
  required Future<void> Function(LocalDatabaseAdapter) createBrokenTable,
  required String adapterName,
}) {
```

- [ ] **Step 2: Append the schema validation group**

Inside the existing `group('$adapterName — LocalDatabaseAdapter contract', () { ... })`, after the `transaction atomicity` group, add:

```dart
    group('schema validation', () {
      test('passes when every required column is present', () async {
        await adapter.validateSchema(['things']);
      });

      test('throws SchemaValidationException listing missing columns', () async {
        await createBrokenTable(adapter);
        SchemaValidationException? caught;
        try {
          await adapter.validateSchema(['broken']);
        } on SchemaValidationException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.table, 'broken');
        expect(
          caught.missingColumns.toSet(),
          {
            SyncColumns.updatedAt,
            SyncColumns.deletedAt,
            SyncColumns.isSynced,
            SyncColumns.syncStatus,
          },
        );
      });
    });
```

- [ ] **Step 3: Update `test/contract_suite_test.dart` to supply `createBrokenTable`**

Replace the whole file with:

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/src/testing/local_database_adapter_contract.dart';

import 'support/in_memory_adapter.dart';

void main() {
  runLocalDatabaseAdapterContract(
    factory: InMemoryAdapter.new,
    adapterName: 'InMemoryAdapter',
    createTestTable: (a) async {
      (a as InMemoryAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
    createBrokenTable: (a) async {
      (a as InMemoryAdapter).registerTable('broken', const [
        'id',
        'created_at',
      ]);
    },
  );
}
```

- [ ] **Step 4: Run the full suite**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test test/contract_suite_test.dart
dart analyze
```
Expected: 20 tests pass in total (8 + 7 + 3 + 2); no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/src/testing/local_database_adapter_contract.dart \
        packages/flutter_universal_sync_core/test/contract_suite_test.dart
git commit -m "test(core): contract suite — schema validation"
```

---

## Task 19: Testing barrel export

**Files:**
- Create: `packages/flutter_universal_sync_core/lib/testing.dart`

A dedicated barrel for the `testing/` subfolder so downstream adapter packages import the contract suite via `package:flutter_universal_sync_core/testing.dart` without pulling `test/` concerns into the production barrel.

- [ ] **Step 1: Write the testing barrel**

Path: `lib/testing.dart`

```dart
/// Test utilities for consumers of `flutter_universal_sync_core`.
///
/// Import this library (not `flutter_universal_sync_core.dart`) from
/// adapter packages' `test/` suites to access the shared
/// `runLocalDatabaseAdapterContract` helper.
library;

export 'src/testing/local_database_adapter_contract.dart';
```

- [ ] **Step 2: Update `test/contract_suite_test.dart` to import via the testing barrel (not the internal path)**

Replace the `import 'package:flutter_universal_sync_core/src/testing/...';` line with:

```dart
import 'package:flutter_universal_sync_core/testing.dart';
```

Final file:

```dart
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';

import 'support/in_memory_adapter.dart';

void main() {
  runLocalDatabaseAdapterContract(
    factory: InMemoryAdapter.new,
    adapterName: 'InMemoryAdapter',
    createTestTable: (a) async {
      (a as InMemoryAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
    createBrokenTable: (a) async {
      (a as InMemoryAdapter).registerTable('broken', const [
        'id',
        'created_at',
      ]);
    },
  );
}
```

- [ ] **Step 3: Run tests and analyzer**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test
dart analyze
```
Expected: every test in every file passes (enum, status, entity, queue entry, columns, errors, id, 3 resolvers, barrel, 20 contract-suite tests); no analyzer issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/lib/testing.dart \
        packages/flutter_universal_sync_core/test/contract_suite_test.dart
git commit -m "feat(core): add testing barrel export"
```

---

## Task 20: CI workflow (GitHub Actions)

**Files:**
- Create: `.github/workflows/core.yml`

- [ ] **Step 1: Write the CI workflow**

Path (from the monorepo root): `.github/workflows/core.yml`

```yaml
name: core

on:
  push:
    branches: [main]
    paths:
      - 'packages/flutter_universal_sync_core/**'
      - '.github/workflows/core.yml'
  pull_request:
    paths:
      - 'packages/flutter_universal_sync_core/**'
      - '.github/workflows/core.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/flutter_universal_sync_core
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: '3.4.0'
      - run: dart pub get
      - run: dart analyze --fatal-infos
      - run: dart test --coverage=coverage
      - run: dart pub global activate coverage
      - run: dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
      - name: Enforce coverage >= 95%
        run: |
          LINE_RATE=$(awk -F: '
            /^DA:/ {
              split($2, a, ","); total++;
              if (a[2] > 0) hit++;
            }
            END {
              if (total == 0) { print "0"; exit }
              printf "%.2f\n", hit/total*100
            }
          ' coverage/lcov.info)
          echo "Coverage: $LINE_RATE%"
          awk -v rate="$LINE_RATE" 'BEGIN { exit (rate+0 < 95.0) ? 1 : 0 }'
```

- [ ] **Step 2: Verify the YAML is valid locally**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/core.yml'))" && echo "YAML ok"
```
Expected: `YAML ok`.

- [ ] **Step 3: Verify coverage math on the local suite**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
awk -F: '/^DA:/ { split($2,a,","); total++; if (a[2]>0) hit++ } END { printf "%.2f\n", hit/total*100 }' coverage/lcov.info
```
Expected: printed number ≥ 95.00. If lower, look at `coverage/lcov.info` for uncovered lines and add tests before committing.

- [ ] **Step 4: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add .github/workflows/core.yml
git commit -m "ci: add flutter_universal_sync_core workflow"
```

---

## Task 21: Core package README

**Files:**
- Create: `packages/flutter_universal_sync_core/README.md`

- [ ] **Step 1: Write the README**

Path: `packages/flutter_universal_sync_core/README.md`

```markdown
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
```

- [ ] **Step 2: Verify no dead links / broken code blocks**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
ls README.md LICENSE CHANGELOG.md pubspec.yaml
```
Expected: all four listed.

- [ ] **Step 3: Commit**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/README.md
git commit -m "docs(core): add package README"
```

---

## Task 22: `dart pub publish --dry-run` verification

Gate task — no files output, but you MUST resolve any warning that would block publishing.

- [ ] **Step 1: Run the dry-run**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart pub publish --dry-run
```
Expected (acceptable): 0 errors. Warnings about `homepage`/`repository`/`issue_tracker` URLs containing `REPLACE_ME` are expected — the user will set the GitHub org before actual publish.

- [ ] **Step 2: Address any unexpected warnings**

Typical issues and fixes:

| Warning | Fix |
|---------|-----|
| "description is too short" | Extend the `description:` in `pubspec.yaml` to ≥ 60 chars (already satisfied by Task 1 — confirm). |
| "README missing" | Should be present from Task 21 — re-verify it's at `packages/flutter_universal_sync_core/README.md`. |
| "CHANGELOG missing" | Should be present from Task 1 — confirm the stub exists. |
| "No LICENSE file" | Created in Task 1 — confirm. |
| Files not under version control | Stage any newly-created file (`git add ...`). |
| "public_member_api_docs" violations | Every public symbol should have a doc comment from Tasks 2–13; add any that's missing. |

Do NOT replace `REPLACE_ME` yet — that's a deliberate placeholder the user will fill when choosing a GitHub org pre-publish.

- [ ] **Step 3: Re-run and verify**

```bash
dart pub publish --dry-run
```
Expected: `Package has 0 warnings` OR only the `REPLACE_ME` URL warnings (which are expected).

- [ ] **Step 4: No commit needed** — dry-run produces no file changes. Confirm working tree is clean:

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git status
```
Expected: `nothing to commit, working tree clean`.

---

## Task 23: CHANGELOG finalization

**Files:**
- Modify: `packages/flutter_universal_sync_core/CHANGELOG.md`

- [ ] **Step 1: Replace the `Unreleased` stub with the `0.1.0` entry**

Path: `packages/flutter_universal_sync_core/CHANGELOG.md`

```markdown
# Changelog

## 0.1.0 — 2026-04-24

Initial release. Contracts layer for the `flutter_universal_sync` family.

### Added
- `SyncEntity` abstract base class with the six sync-metadata fields.
- `SyncQueueEntry` data class with `copyWith`, `toMap`/`fromMap`, and structural equality.
- `SyncOperation` (`insert` / `update` / `delete`) and `SyncStatus` (`pending` / `syncing` / `synced` / `failed`) enums.
- `LocalDatabaseAdapter` interface covering domain CRUD, sync queue, atomic transactions, and schema validation.
- `RemoteSyncAdapter` interface for per-op push and delta pull.
- `ConflictResolver` interface plus three built-in strategies: `LastWriteWinsResolver`, `ServerPriorityResolver`, `ClientPriorityResolver`.
- `SyncColumns` schema constants.
- `SyncException` sealed hierarchy (`SchemaValidationException`, `SyncPushException`, `SyncPullException`, `ConflictResolutionException`).
- `IdGenerator` / `UuidV4Generator`.
- Shared `runLocalDatabaseAdapterContract` test suite for downstream adapter packages (exported via `package:flutter_universal_sync_core/testing.dart`).

### Known limitations
See README "Known v1 limitations" for the list of accepted `0.1.0` trade-offs.
```

- [ ] **Step 2: Final full verification**

Run every check one more time to confirm success criteria are met:

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync/packages/flutter_universal_sync_core
dart pub get
dart analyze --fatal-infos
dart test
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
awk -F: '/^DA:/ { split($2,a,","); total++; if (a[2]>0) hit++ } END { printf "%.2f\n", hit/total*100 }' coverage/lcov.info
dart pub publish --dry-run
```

Expected outputs:
- `dart analyze --fatal-infos`: `No issues found!`
- `dart test`: every group passes; total ≥ 40 tests.
- Coverage: ≥ 95.00
- `dart pub publish --dry-run`: 0 errors (expected `REPLACE_ME` URL warnings only).

- [ ] **Step 3: Commit the CHANGELOG**

```bash
cd /Users/himanshusharma/Documents/flutter_universal_sync
git add packages/flutter_universal_sync_core/CHANGELOG.md
git commit -m "docs(core): finalize 0.1.0 CHANGELOG entry"
```

- [ ] **Step 4: Confirm Plan 1 success criteria**

Check each criterion from the spec's §14:

| # | Criterion | How to verify |
|---|-----------|--------------|
| 1 | Monorepo initialized with git | `cd /Users/himanshusharma/Documents/flutter_universal_sync && git log --oneline | head -n 1` shows at least one commit |
| 2 | `packages/flutter_universal_sync_core/` exists, passes analyze | Verified in Step 2 above |
| 3 | Every public type implemented and exported | `grep -E '^export' packages/flutter_universal_sync_core/lib/flutter_universal_sync_core.dart | wc -l` → 13 |
| 4 | Coverage ≥ 95% | Verified in Step 2 above |
| 5 | Contract suite exists; validated by the in-memory stub | `ls packages/flutter_universal_sync_core/lib/src/testing/ packages/flutter_universal_sync_core/test/support/` shows both files; `dart test test/contract_suite_test.dart` green |
| 6 | CI workflow exists | `ls .github/workflows/core.yml` |
| 7 | README documents install + public types + known limitations + topology | Open the README; confirm all four sections |
| 8 | CHANGELOG has 0.1.0 entry | Step 1 above |
| 9 | `dart pub publish --dry-run` passes | Verified in Step 2 above |

If every line checks out, Plan 1 is complete.

---

## Plan self-review notes

Applied inline during plan writing:

- **Spec coverage:** every public type in spec §§4–9 has a build task (Tasks 2–12); contract suite (Tasks 15–18) covers spec §10; testing strategy (Tasks 20, 22) covers spec §11; known limitations → README in Task 21; public API surface → barrel in Task 13 + testing barrel in Task 19; success criteria checked in Task 23 Step 4.
- **Type consistency:** method signatures for `LocalDatabaseAdapter.update` declared in Task 11 match the patch-semantics test in Task 15; `SyncQueueEntry` fields used in Tasks 5, 15, 16, 17 are identical; `recordSyncFailure(queueEntryId, error)` signature consistent between Task 11 declaration and Task 16 usage; `LastWriteWinsResolver` timestamp-type handling consistent between Task 9 test and implementation.
- **No placeholders:** every code block contains runnable code; no "TODO" or "similar to" references. `REPLACE_ME` in URLs is intentional and documented as such in Task 22.
