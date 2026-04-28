import 'package:flutter_universal_sync_core/src/conflict/server_priority_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('ServerPriorityResolver', () {
    test('always returns the remote row', () {
      final local = {'id': 'a', 'name': 'local'};
      final remote = {'id': 'a', 'name': 'remote'};
      expect(const ServerPriorityResolver().resolve(local, remote), remote);
    });

    test('returns the remote row even when local has more fields', () {
      expect(
        const ServerPriorityResolver().resolve(
          {'id': 'a', 'name': 'local', 'extra': 1},
          {'id': 'a', 'name': 'remote'},
        ),
        {'id': 'a', 'name': 'remote'},
      );
    });
  });
}
