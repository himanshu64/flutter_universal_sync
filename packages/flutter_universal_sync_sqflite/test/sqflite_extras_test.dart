import 'package:flutter_universal_sync_sqflite/flutter_universal_sync_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  SqfliteSyncAdapter newAdapter() => SqfliteSyncAdapter(
        databaseFactory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  late SqfliteSyncAdapter adapter;

  setUp(() async {
    adapter = newAdapter();
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

  test('database getter throws before init', () {
    expect(() => newAdapter().database, throwsStateError);
  });

  test('encodes bool, DateTime, and nested values for binding', () async {
    await adapter.upsert('things', {
      'id': 'e1',
      'created_at': DateTime.utc(2026, 1, 1),
      'updated_at': 1000,
      'deleted_at': null,
      'is_synced': true,
      'sync_status': 'pending',
      'name': {'nested': 'json'},
    });
    final row = await adapter.getById('things', 'e1');
    expect(row, isNotNull);
    expect(row!['is_synced'], 1); // bool -> int
    expect(row['created_at'], DateTime.utc(2026, 1, 1).millisecondsSinceEpoch);
    expect(row['name'], contains('nested')); // Map -> jsonEncode
  });

  test('nested transaction runs inline and commits', () async {
    await adapter.transaction(() async {
      await adapter.transaction(() async {
        await adapter.insert('things', {
          'id': 'n1',
          'created_at': 1,
          'updated_at': 1,
          'deleted_at': null,
          'is_synced': 0,
          'sync_status': 'pending',
          'name': 'inner',
        });
      });
    });
    expect(await adapter.getById('things', 'n1'), isNotNull);
  });
}
