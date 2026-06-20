import 'package:drift/native.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_drift/flutter_universal_sync_drift.dart';

void main() {
  runLocalDatabaseAdapterContract(
    adapterName: 'DriftSyncAdapter',
    factory: () => DriftSyncAdapter(executor: NativeDatabase.memory()),
    createTestTable: (a) async {
      await (a as DriftSyncAdapter).database.customStatement('''
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
      await (a as DriftSyncAdapter).database.customStatement(
            'CREATE TABLE broken '
            '(id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL)',
          );
    },
  );
}
