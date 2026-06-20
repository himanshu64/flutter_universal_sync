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
  required Future<void> Function(LocalDatabaseAdapter) createBrokenTable,
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
          SyncColumns.createdAt: 1700000000000,
          SyncColumns.updatedAt: updatedAt ?? 1700000000000,
          SyncColumns.deletedAt: deletedAt,
          SyncColumns.isSynced: 0,
          SyncColumns.syncStatus: 'pending',
          if (name != null) 'name': name,
        };

    // Returns the per-test [adapter] (re-created fresh in [setUp]). The
    // 0.2.0 contract groups below were authored against this helper.
    Future<LocalDatabaseAdapter> openAdapter() async => adapter;

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
          SyncColumns.updatedAt: 1700000005000,
        });
        final row = await adapter.getById('things', 't1');
        expect(row!['name'], 'banana');
        // createdAt NOT passed to update — must be unchanged
        expect(row[SyncColumns.createdAt], 1700000000000);
        expect(row[SyncColumns.updatedAt], 1700000005000);
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
            reason: 'soft-deleted rows must not be hard-removed',);
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
          ),);
        });
        expect(await adapter.getById('things', 't1'), isNotNull);
        expect((await adapter.pendingSyncEntries()).map((e) => e.id), ['q1']);
      });

      test('throwing transaction rolls back both writes', () async {
        bool threw = false;
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
            ),);
            throw StateError('rollback please');
          });
        } on StateError {
          threw = true;
        }
        expect(threw, isTrue, reason: 'transaction should have thrown',);
        expect(await adapter.getById('things', 't1'), isNull,
            reason: 'domain write must roll back',);
        expect(await adapter.pendingSyncEntries(), isEmpty,
            reason: 'queue write must roll back',);
      });

      test('exception from nested operation still rolls back everything',
          () async {
        // Row exists before the transaction; attempting to re-insert throws.
        await adapter.insert('things', thingRow(id: 'existing', name: 'old'));
        try {
          await adapter.transaction(() async {
            await adapter.update('things', 'existing', {
              'name': 'new',
              SyncColumns.updatedAt: 1700000005000,
            });
            // This second insert fails (duplicate id).
            await adapter.insert('things', thingRow(id: 'existing'));
          });
          fail('should have thrown');
        } on StateError catch (_) {/* expected */}
        final row = await adapter.getById('things', 'existing');
        expect(row!['name'], 'old',
            reason: 'earlier update must be rolled back too',);
      });
    });

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
            ),);
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
            nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 1),);
        await adapter.recordSyncFailure('q1', 'e2',
            nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 4),);
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
                nextRetryAt: DateTime.utc(2026, 1, 1, 12, 0, 10),);
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
  });
}
