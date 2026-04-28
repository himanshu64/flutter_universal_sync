import 'package:flutter_universal_sync_core/src/conflict/client_priority_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('ClientPriorityResolver', () {
    test('always returns the local row', () {
      final local = {'id': 'a', 'name': 'local'};
      final remote = {'id': 'a', 'name': 'remote'};
      expect(const ClientPriorityResolver().resolve(local, remote), local);
    });

    test('returns the local row even when remote has more fields', () {
      expect(
        const ClientPriorityResolver().resolve(
          {'id': 'a', 'name': 'local'},
          {'id': 'a', 'name': 'remote', 'extra': 1},
        ),
        {'id': 'a', 'name': 'local'},
      );
    });
  });
}
