import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/src/testing/local_database_adapter_contract.dart';

import 'support/in_memory_adapter.dart';

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
  );
}
