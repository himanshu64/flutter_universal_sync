import 'package:flutter_universal_sync_core/src/conflict/last_write_wins_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('LastWriteWinsResolver', () {
    final earlier = DateTime.utc(2026, 4, 24, 10, 0, 0);
    final later = DateTime.utc(2026, 4, 24, 11, 0, 0);

    test('returns the row with the later DateTime updated_at', () {
      final local = {'id': 'a', 'updated_at': later, 'name': 'local'};
      final remote = {'id': 'a', 'updated_at': earlier, 'name': 'remote'};
      expect(const LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('remote wins when its updated_at is later', () {
      final local = {'id': 'a', 'updated_at': earlier};
      final remote = {'id': 'a', 'updated_at': later};
      expect(const LastWriteWinsResolver().resolve(local, remote), remote);
    });

    test('on exact tie, remote wins (deterministic tiebreak)', () {
      final local = {'id': 'a', 'updated_at': later, 'name': 'local'};
      final remote = {'id': 'a', 'updated_at': later, 'name': 'remote'};
      expect(const LastWriteWinsResolver().resolve(local, remote), remote);
    });

    test('accepts ISO-8601 strings for updated_at', () {
      final local = {'id': 'a', 'updated_at': later.toIso8601String()};
      final remote = {'id': 'a', 'updated_at': earlier.toIso8601String()};
      expect(const LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('accepts millisSinceEpoch ints for updated_at', () {
      final local = {'id': 'a', 'updated_at': later.millisecondsSinceEpoch};
      final remote = {'id': 'a', 'updated_at': earlier.millisecondsSinceEpoch};
      expect(const LastWriteWinsResolver().resolve(local, remote), local);
    });

    test('throws ArgumentError if updated_at is missing', () {
      expect(
        () => const LastWriteWinsResolver().resolve({'id': 'a'}, {'id': 'a'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for unsupported updated_at type', () {
      expect(
        () => const LastWriteWinsResolver().resolve(
          {'id': 'a', 'updated_at': <String, dynamic>{}},
          {'id': 'a', 'updated_at': <String, dynamic>{}},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
