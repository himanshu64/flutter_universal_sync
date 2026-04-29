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
  });
}
