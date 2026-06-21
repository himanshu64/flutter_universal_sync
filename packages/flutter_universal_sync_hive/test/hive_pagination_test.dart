import 'dart:io';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:test/test.dart';

void main() {
  final cols = [...SyncColumns.required, 'name'];

  Future<HiveSyncAdapter> open() async {
    final dir = Directory.systemTemp.createTempSync('hive_page').path;
    final a = HiveSyncAdapter(directory: dir)..registerTable('things', cols);
    await a.init();
    return a;
  }

  Future<void> put(HiveSyncAdapter a, String id, int updatedAt,
          {int? deletedAt}) =>
      a.upsert('things', {
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
    final a = await open();
    for (final e
        in {'a': 100, 'b': 200, 'c': 300, 'd': 400, 'e': 500}.entries) {
      await put(a, e.key, e.value);
    }

    final p1 = await a.getPage('things', limit: 2);
    expect(ids(p1), ['e', 'd']);
    final p2 = await a.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['c', 'b']);
    final p3 = await a.getPage('things', limit: 2, after: p2.nextCursor);
    expect(ids(p3), ['a']);
    expect(p3.hasMore, isFalse);
    await a.close();
  });

  test('keyset paging is stable across inserts/deletes', () async {
    final a = await open();
    for (final e in {'a': 100, 'b': 200, 'c': 300, 'd': 400}.entries) {
      await put(a, e.key, e.value);
    }

    final p1 = await a.getPage('things', limit: 2); // [d, c]
    expect(ids(p1), ['d', 'c']);

    await a.delete('things', 'd');
    await put(a, 'z', 450);

    final p2 = await a.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['b', 'a']);
    await a.close();
  });

  test('filters soft-deletes unless includeDeleted', () async {
    final a = await open();
    await put(a, 'a', 100);
    await put(a, 'b', 200, deletedAt: 999);

    expect(ids(await a.getPage('things')), ['a']);
    expect(ids(await a.getPage('things', includeDeleted: true)), ['b', 'a']);
    await a.close();
  });
}
