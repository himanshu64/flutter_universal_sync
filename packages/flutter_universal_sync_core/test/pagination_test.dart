import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> row(String id, int updatedAt, {int? deletedAt}) => {
        SyncColumns.id: id,
        SyncColumns.updatedAt: updatedAt,
        SyncColumns.deletedAt: deletedAt,
      };

  Future<InMemoryAdapter> seed(List<Map<String, dynamic>> rows) async {
    final a = InMemoryAdapter();
    for (final r in rows) {
      await a.upsert('things', r);
    }
    return a;
  }

  List<String> ids(PageResult p) =>
      p.rows.map((r) => r[SyncColumns.id] as String).toList();

  test('pages newest-first by updated_at and exhausts cleanly', () async {
    final a = await seed([
      row('a', 100),
      row('b', 200),
      row('c', 300),
      row('d', 400),
      row('e', 500),
    ]);

    final p1 = await a.getPage('things', limit: 2);
    expect(ids(p1), ['e', 'd']);
    expect(p1.hasMore, isTrue);

    final p2 = await a.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['c', 'b']);

    final p3 = await a.getPage('things', limit: 2, after: p2.nextCursor);
    expect(ids(p3), ['a']);
    expect(p3.hasMore, isFalse); // short page → no further cursor
  });

  test('keyset paging is stable when rows are inserted/deleted mid-scan',
      () async {
    final a = await seed([
      row('a', 100),
      row('b', 200),
      row('c', 300),
      row('d', 400),
    ]);

    final p1 = await a.getPage('things', limit: 2); // [d, c]
    expect(ids(p1), ['d', 'c']);

    // Mutate the prefix already seen — under OFFSET paging this would shift the
    // window and duplicate or skip a row. Keyset anchors on (value,id).
    await a.delete('things', 'd'); // soft-delete a seen row
    await a.upsert('things', row('z', 450)); // insert above the cursor

    final p2 = await a.getPage('things', limit: 2, after: p1.nextCursor);
    expect(ids(p2), ['b', 'a']); // continues exactly after 'c', no dup/skip
  });

  test('orders ascending and by a custom column with id tiebreak', () async {
    final a = await seed([
      row('a', 100),
      row('b', 100), // tie on updated_at → id breaks it
      row('c', 200),
    ]);

    final asc = await a.getPage('things', descending: false, limit: 10);
    expect(ids(asc), ['a', 'b', 'c']);
  });

  test('excludes soft-deleted rows unless includeDeleted', () async {
    final a = await seed([
      row('a', 100),
      row('b', 200, deletedAt: 999),
    ]);

    expect(ids(await a.getPage('things')), ['a']);
    expect(ids(await a.getPage('things', includeDeleted: true)), ['b', 'a']);
  });

  test('handles null ordering values without crashing', () async {
    final a = InMemoryAdapter();
    await a.upsert('things', {SyncColumns.id: 'x', 'rank': null});
    await a.upsert('things', {SyncColumns.id: 'y', 'rank': null});
    await a.upsert('things', {SyncColumns.id: 'z', 'rank': 5});

    final page = await a.getPage('things', orderBy: 'rank', limit: 10);
    expect(ids(page).toSet(), {'x', 'y', 'z'});
  });

  test('returns an empty page for an unknown table', () async {
    final a = await seed([row('a', 100)]);
    final p = await a.getPage('ghosts');
    expect(p.rows, isEmpty);
    expect(p.hasMore, isFalse);
  });
}
