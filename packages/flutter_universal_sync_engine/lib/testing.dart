/// Test doubles for downstream packages that integration-test against
/// the engine's contracts. Import this barrel from your `dev_dependencies`
/// — never from production code.
library;

export 'src/testing/fake_connectivity_monitor.dart';
export 'src/testing/fake_remote_sync_adapter.dart';
