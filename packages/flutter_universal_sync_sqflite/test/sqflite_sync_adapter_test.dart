import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_sqflite/flutter_universal_sync_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  runLocalDatabaseAdapterContract(
    adapterName: 'SqfliteSyncAdapter',
    factory: () => SqfliteSyncAdapter(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    ),
    createTestTable: (a) async {
      await (a as SqfliteSyncAdapter).database.execute('''
        CREATE TABLE things (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          is_synced INTEGER NOT NULL DEFAULT 0,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          name TEXT
        )
      ''');
    },
    createBrokenTable: (a) async {
      await (a as SqfliteSyncAdapter).database.execute(
        'CREATE TABLE broken '
        '(id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL)',
      );
    },
  );
}
