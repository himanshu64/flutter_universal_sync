import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';

void main() {
  runLocalDatabaseAdapterContract(
    factory: InMemoryAdapter.new,
    adapterName: 'InMemoryAdapter',
    createTestTable: (a) async {
      (a as InMemoryAdapter).registerTable('things', [
        ...SyncColumns.required,
        'name',
      ]);
    },
    createBrokenTable: (a) async {
      (a as InMemoryAdapter).registerTable('broken', const [
        'id',
        'created_at',
      ]);
    },
  );
}
