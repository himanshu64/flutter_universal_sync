import 'package:test/test.dart';

import '../adapters/remote_sync_adapter.dart';
import '../entities/sync_operation.dart';
import '../entities/sync_queue_entry.dart';
import '../schema/sync_columns.dart';

/// Couples a [RemoteSyncAdapter] under test to the backend it talks to, so the
/// contract can both drive the adapter and inspect/seed that backend directly.
///
/// Implement this for your custom adapter (e.g. wrap a `MockClient` over an
/// in-memory map, or point at a disposable test database), then hand it to
/// [runRemoteSyncAdapterContract].
abstract class RemoteAdapterHarness {
  /// The adapter under test, already wired to the backend.
  RemoteSyncAdapter get adapter;

  /// Writes [rows] straight into the backend, bypassing the adapter — used to
  /// set up pull-side scenarios.
  Future<void> seed(String table, List<Map<String, dynamic>> rows);

  /// Returns the backend's current rows for [table], so the contract can verify
  /// that pushes actually landed.
  Future<List<Map<String, dynamic>>> backendRows(String table);

  /// Releases resources (close HTTP clients, drop test data, …).
  Future<void> dispose();
}

/// Runs the shared `RemoteSyncAdapter` behavioural contract against the adapter
/// produced by [newHarness] — the remote-side counterpart of
/// `runLocalDatabaseAdapterContract`.
///
/// Call it from your custom remote adapter's test file with a harness that
/// wires the adapter to a controllable backend:
///
/// ```dart
/// runRemoteSyncAdapterContract(
///   adapterName: 'MyApiAdapter',
///   newHarness: () => MyApiHarness(),
/// );
/// ```
void runRemoteSyncAdapterContract({
  required String adapterName,
  required RemoteAdapterHarness Function() newHarness,
  String table = 'things',
}) {
  group('$adapterName — RemoteSyncAdapter contract', () {
    late RemoteAdapterHarness harness;

    setUp(() => harness = newHarness());
    tearDown(() => harness.dispose());

    Map<String, dynamic> row(
      String id, {
      int updatedAt = 1000,
      int? deletedAt,
      String? name,
    }) =>
        {
          SyncColumns.id: id,
          SyncColumns.createdAt: 1000,
          SyncColumns.updatedAt: updatedAt,
          SyncColumns.deletedAt: deletedAt,
          SyncColumns.isSynced: 1,
          SyncColumns.syncStatus: 'synced',
          'name': name ?? id,
        };

    SyncQueueEntry entry(SyncOperation op, Map<String, dynamic> payload) =>
        SyncQueueEntry(
          id: 'q-${payload[SyncColumns.id]}-${op.name}',
          table: table,
          entityId: payload[SyncColumns.id] as String,
          operation: op,
          payload: payload,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    Iterable<Object?> idsOf(List<Map<String, dynamic>> rows) =>
        rows.map((r) => r[SyncColumns.id]);

    group('pullChanges', () {
      test('returns an empty list for an empty backend', () async {
        expect(await harness.adapter.pullChanges(table, null), isEmpty);
      });

      test('returns seeded rows carrying id and updated_at', () async {
        await harness.seed(table, [row('a'), row('b', updatedAt: 2000)]);
        final rows = await harness.adapter.pullChanges(table, null);
        expect(idsOf(rows), containsAll(<String>['a', 'b']));
        for (final r in rows) {
          expect(r[SyncColumns.id], isNotNull);
          expect(r[SyncColumns.updatedAt], isNotNull);
        }
      });
    });

    group('pushChange', () {
      test('insert lands in the backend', () async {
        await harness.adapter.pushChange(
          entry(SyncOperation.insert, row('a')),
        );
        expect(idsOf(await harness.backendRows(table)), contains('a'));
      });

      test('update is reflected in the backend', () async {
        await harness.adapter.pushChange(
          entry(SyncOperation.insert, row('a', updatedAt: 1000)),
        );
        await harness.adapter.pushChange(
          entry(
            SyncOperation.update,
            row('a', updatedAt: 2000, name: 'renamed'),
          ),
        );
        final backend = await harness.backendRows(table);
        final a = backend.firstWhere((r) => r[SyncColumns.id] == 'a');
        expect(a['name'], 'renamed');
      });

      test('a pushed insert becomes pullable (round-trip)', () async {
        await harness.adapter.pushChange(
          entry(SyncOperation.insert, row('a')),
        );
        final pulled = await harness.adapter.pullChanges(table, null);
        expect(idsOf(pulled), contains('a'));
      });

      test('delete removes or tombstones the row', () async {
        await harness.adapter.pushChange(
          entry(SyncOperation.insert, row('a')),
        );
        await harness.adapter.pushChange(
          entry(SyncOperation.delete, row('a', deletedAt: 5000)),
        );
        final match = (await harness.backendRows(
          table,
        ))
            .where((r) => r[SyncColumns.id] == 'a');
        final goneOrTombstoned =
            match.isEmpty || match.first[SyncColumns.deletedAt] != null;
        expect(
          goneOrTombstoned,
          isTrue,
          reason: 'delete should remove the row or set deleted_at',
        );
      });
    });
  });
}
