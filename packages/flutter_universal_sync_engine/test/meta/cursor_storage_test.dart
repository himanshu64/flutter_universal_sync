import 'package:flutter_universal_sync_core/testing.dart';
import 'package:flutter_universal_sync_engine/src/meta/meta_keys.dart';
import 'package:test/test.dart';

void main() {
  test('pullCursor key format', () {
    expect(MetaKeys.pullCursor('users'), 'pull_cursor:users');
    expect(MetaKeys.pullCursor('orders'), 'pull_cursor:orders');
  });

  test('round-trip via InMemoryAdapter', () async {
    final adapter = InMemoryAdapter();
    final iso = DateTime.utc(2026, 1, 1).toIso8601String();
    await adapter.setMeta(MetaKeys.pullCursor('users'), iso);
    expect(await adapter.getMeta(MetaKeys.pullCursor('users')), iso);
  });
}
