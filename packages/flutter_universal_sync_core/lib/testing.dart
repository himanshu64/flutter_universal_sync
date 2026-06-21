/// Test utilities for consumers of `flutter_universal_sync_core`.
///
/// Import this library (not `flutter_universal_sync_core.dart`) from
/// adapter packages' `test/` suites to access the shared
/// `runLocalDatabaseAdapterContract` and `runRemoteSyncAdapterContract`
/// helpers.
library;

export 'src/testing/in_memory_adapter.dart';
export 'src/testing/local_database_adapter_contract.dart';
export 'src/testing/remote_sync_adapter_contract.dart';
