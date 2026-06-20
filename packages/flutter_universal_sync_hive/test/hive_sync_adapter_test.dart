import 'dart:io';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';

void main() {
  runLocalDatabaseAdapterContract(
    adapterName: 'HiveSyncAdapter',
    factory: () => HiveSyncAdapter(
      directory: Directory.systemTemp.createTempSync('hive_sync').path,
    ),
    createTestTable: (a) async {
      (a as HiveSyncAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
    createBrokenTable: (a) async {
      (a as HiveSyncAdapter)
          .registerTable('broken', const ['id', 'created_at']);
    },
  );
}
