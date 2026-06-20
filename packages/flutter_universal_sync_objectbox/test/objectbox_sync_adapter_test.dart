@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_objectbox/flutter_universal_sync_objectbox.dart';

// Runs once generated bindings (`dart run build_runner build`) and the
// ObjectBox native library are present. See README "Building".
void main() {
  runLocalDatabaseAdapterContract(
    adapterName: 'ObjectboxSyncAdapter',
    factory: () => ObjectboxSyncAdapter(
      directory: Directory.systemTemp.createTempSync('obx_sync').path,
    ),
    createTestTable: (a) async {
      (a as ObjectboxSyncAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
    createBrokenTable: (a) async {
      (a as ObjectboxSyncAdapter)
          .registerTable('broken', const ['id', 'created_at']);
    },
  );
}
