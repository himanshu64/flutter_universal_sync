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

  Future<void> put(String id, int updatedAt, {int? deletedAt}) =>
      adapter.upsert('things', {
        SyncColumns.id: id,
        'name': id,
        SyncColumns.createdAt: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: deletedAt,
        SyncColumns.isSynced: 1,
        SyncColumns.syncStatus: 'synced',
      });

  List<String> ids(PageResult p) =>
      p.rows.map((r) => r[SyncColumns.id] as String).toList();

  test('pages newest-first and exhausts cleanly', () async {
    for (final e
        in {'a': 100, 'b': 200, 'c': 300, 'd': 400, 'e': 500}.entries) {
      await put(e.key, e.value);
    }

    final p1 = await adapter.getPage('things', limit: 2);
    expect(ids(p1), ['e', 'd']);
    final p2 = await adapter.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['c', 'b']);
    final p3 = await adapter.getPage('things', limit: 2, after: p2.nextCursor);
    expect(ids(p3), ['a']);
    expect(p3.hasMore, isFalse);
  });

  test('keyset paging is stable across inserts/deletes', () async {
    for (final e in {'a': 100, 'b': 200, 'c': 300, 'd': 400}.entries) {
      await put(e.key, e.value);
    }

    final p1 = await adapter.getPage('things', limit: 2); // [d, c]
    expect(ids(p1), ['d', 'c']);

    await adapter.delete('things', 'd');
    await put('z', 450);

    final p2 = await adapter.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['b', 'a']);
  });

  test('orders ascending with id tiebreak and filters soft-deletes', () async {
    await put('a', 100);
    await put('b', 100); // tie → id breaks
    await put('c', 200, deletedAt: 999);

    final asc = await adapter.getPage('things', descending: false, limit: 10);
    expect(ids(asc), ['a', 'b']);
    final withDeleted = await adapter.getPage(
      'things',
      descending: false,
      includeDeleted: true,
    );
    expect(ids(withDeleted), ['a', 'b', 'c']);
  });
}
