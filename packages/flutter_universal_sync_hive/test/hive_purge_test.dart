import 'dart:io';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:test/test.dart';

void main() {
  final cols = [...SyncColumns.required, 'name'];

  Map<String, dynamic> row(
    String id, {
    int updatedAt = 1,
    bool synced = true,
  }) =>
      {
        SyncColumns.id: id,
        'name': id,
        SyncColumns.createdAt: 1,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: null,
        SyncColumns.isSynced: synced ? 1 : 0,
        SyncColumns.syncStatus: synced ? 'synced' : 'pending',
      };

  Future<HiveSyncAdapter> open() async {
    final dir = Directory.systemTemp.createTempSync('hive_purge').path;
    final a = HiveSyncAdapter(directory: dir)..registerTable('things', cols);
    await a.init();
    return a;
  }

  test('removes synced rows older than the cutoff, keeps pending', () async {
    final a = await open();
    await a.upsert('things', row('old', updatedAt: 1000));
    await a.upsert('things', row('new', updatedAt: 5000));
    await a.upsert('things', row('pend', updatedAt: 1, synced: false));

    final removed = await a.purgeSynced(
      'things',
      olderThan: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
    );
    expect(removed, 1);
    final ids =
        (await a.getAll('things')).map((r) => r[SyncColumns.id]).toSet();
    expect(ids, {'new', 'pend'});
    await a.close();
  });

  test('keeps the newest N synced rows', () async {
    final a = await open();
    await a.upsert('things', row('a', updatedAt: 1000));
    await a.upsert('things', row('b', updatedAt: 2000));
    await a.upsert('things', row('c', updatedAt: 3000));

    final removed = await a.purgeSynced('things', keepLatest: 1);
    expect(removed, 2);
    expect((await a.getAll('things')).map((r) => r[SyncColumns.id]), ['c']);
    await a.close();
  });

  test('is a no-op without a policy', () async {
    final a = await open();
    await a.upsert('things', row('a'));
    expect(await a.purgeSynced('things'), 0);
    expect((await a.getAll('things')).length, 1);
    await a.close();
  });
}
