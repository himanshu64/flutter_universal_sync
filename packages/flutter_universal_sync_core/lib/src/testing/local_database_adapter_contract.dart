import 'package:test/test.dart';

import '../adapters/local_database_adapter.dart';
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
  });
}
