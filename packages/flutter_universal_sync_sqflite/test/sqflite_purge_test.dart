import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_sqflite/flutter_universal_sync_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late SqfliteSyncAdapter adapter;

  setUp(() async {
    adapter = SqfliteSyncAdapter(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await adapter.init();
    await adapter.database.execute('''
      CREATE TABLE things (
        id TEXT PRIMARY KEY NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        name TEXT
      )
    ''');
  });

  tearDown(() => adapter.close());

  Future<void> put(
    String id, {
    int updatedAt = 1,
    bool synced = true,
  }) =>
      adapter.upsert('things', {
        SyncColumns.id: id,
        'name': id,
        SyncColumns.createdAt: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: synced ? 1 : 0,
        SyncColumns.syncStatus: synced ? 'synced' : 'pending',
      });

  Future<Set<Object?>> ids() async =>
      (await adapter.getAll('things')).map((r) => r[SyncColumns.id]).toSet();

  test('removes synced rows older than the cutoff, keeps pending', () async {
    await put('old', updatedAt: 1000);
    await put('new', updatedAt: 5000);
    await put('pend', updatedAt: 1, synced: false);

    final removed = await adapter.purgeSynced(
      'things',
      olderThan: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
    );
    expect(removed, 1);
    expect(await ids(), {'new', 'pend'});
  });

  test('keeps the newest N synced rows', () async {
    await put('a', updatedAt: 1000);
    await put('b', updatedAt: 2000);
    await put('c', updatedAt: 3000);

    final removed = await adapter.purgeSynced('things', keepLatest: 1);
    expect(removed, 2);
    expect(await ids(), {'c'});
  });

  test('is a no-op without a policy', () async {
    await put('a');
    expect(await adapter.purgeSynced('things'), 0);
    expect(await ids(), {'a'});
  });
}
