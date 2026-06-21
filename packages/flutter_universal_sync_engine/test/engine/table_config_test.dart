import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/src/engine/table_config.dart';
import 'package:test/test.dart';

void main() {
  test('default conflictResolver is LastWriteWinsResolver', () {
    const config = TableConfig();
    expect(config.conflictResolver, isA<LastWriteWinsResolver>());
  });

  test('accepts a custom resolver', () {
    const config = TableConfig(conflictResolver: ServerPriorityResolver());
    expect(config.conflictResolver, isA<ServerPriorityResolver>());
  });
}
