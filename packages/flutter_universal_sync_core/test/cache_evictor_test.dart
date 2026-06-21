import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:test/test.dart';

void main() {
  // Builds a synced row with the given updated_at (ms since epoch).
  Map<String, dynamic> synced(String id, int updatedAt) => {
        SyncColumns.id: id,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.isSynced: 1,
        SyncColumns.syncStatus: 'synced',
      };

  Future<InMemoryAdapter> seed(List<Map<String, dynamic>> rows) async {
    final adapter = InMemoryAdapter();
    adapter.registerTable('photos', {
      SyncColumns.id,
      SyncColumns.updatedAt,
      SyncColumns.isSynced,
      SyncColumns.syncStatus,
    });
    for (final row in rows) {
      await adapter.upsert('photos', row);
    }
    return adapter;
  }

  group('purgeSynced', () {
    test('is a no-op without a policy', () async {
      final adapter = await seed([synced('a', 1000)]);
      expect(await adapter.purgeSynced('photos'), 0);
      expect((await adapter.getAll('photos')).length, 1);
    });

    test('removes synced rows older than the cutoff', () async {
      final adapter = await seed([synced('old', 1000), synced('new', 5000)]);
      final removed = await adapter.purgeSynced(
        'photos',
        olderThan: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
      );
      expect(removed, 1);
      expect((await adapter.getAll('photos')).map((r) => r[SyncColumns.id]), [
        'new',
      ]);
    });

    test('keeps the newest N synced rows', () async {
      final adapter = await seed([
        synced('a', 1000),
        synced('b', 2000),
        synced('c', 3000),
      ]);
      final removed = await adapter.purgeSynced('photos', keepLatest: 1);
      expect(removed, 2);
      expect((await adapter.getAll('photos')).map((r) => r[SyncColumns.id]), [
        'c',
      ]);
    });

    test('never purges unsynced rows', () async {
      final adapter = await seed([
        {
          SyncColumns.id: 'pending',
          SyncColumns.updatedAt: 1000,
          SyncColumns.isSynced: 0,
          SyncColumns.syncStatus: 'pending',
        },
        synced('done', 1000),
      ]);
      final removed = await adapter.purgeSynced(
        'photos',
        olderThan: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );
      expect(removed, 1);
      expect((await adapter.getAll('photos')).map((r) => r[SyncColumns.id]), [
        'pending',
      ]);
    });

    test('returns 0 for an unknown table', () async {
      final adapter = await seed([synced('a', 1000)]);
      expect(await adapter.purgeSynced('ghosts', keepLatest: 0), 0);
    });
  });

  group('CacheEvictor', () {
    test('evicts by maxAge across tables relative to injected now', () async {
      final adapter = await seed([
        synced('old', 1000),
        synced('fresh', 9000000),
      ]);
      final evictor = CacheEvictor(adapter);
      final removed = await evictor.evict(
        ['photos'],
        maxAge: const Duration(seconds: 10),
        now: DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true),
      );
      // cutoff = 1000000ms - 10000ms = 990000ms → 'old' (1000) is purged.
      expect(removed, 1);
      expect((await adapter.getAll('photos')).map((r) => r[SyncColumns.id]), [
        'fresh',
      ]);
    });

    test('evicts by maxRows', () async {
      final adapter = await seed([
        synced('a', 1000),
        synced('b', 2000),
        synced('c', 3000),
      ]);
      final removed = await CacheEvictor(adapter).evict(['photos'], maxRows: 2);
      expect(removed, 1);
      expect(
        (await adapter.getAll('photos')).map((r) => r[SyncColumns.id]).toSet(),
        {'b', 'c'},
      );
    });
  });
}
