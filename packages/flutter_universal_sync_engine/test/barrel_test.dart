import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:test/test.dart';

void main() {
  test('public API surface is reachable through the barrel', () {
    // Just referencing each type is the smoke test. If the barrel ever
    // drops one accidentally, this stops compiling.
    expect(EngineStatus.idle, isNotNull);
    expect(SyncStateSnapshot.idle(pendingCount: 0), isNotNull);
    expect(const TableConfig(), isNotNull);
    expect(defaultBackoff(0), isNotNull);
    expect(ConnectivityMonitor, isNotNull);
    expect(SyncEngine, isNotNull);
  });
}
