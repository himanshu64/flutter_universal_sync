import 'package:flutter_universal_sync_engine/src/engine/engine_status.dart';
import 'package:test/test.dart';

void main() {
  test('three values in declaration order', () {
    expect(EngineStatus.values, [
      EngineStatus.idle,
      EngineStatus.syncing,
      EngineStatus.error,
    ]);
  });

  test('byName round-trips for every value', () {
    for (final v in EngineStatus.values) {
      expect(EngineStatus.values.byName(v.name), v);
    }
  });
}
