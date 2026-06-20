import 'package:flutter_universal_sync_engine/src/engine/backoff.dart';
import 'package:test/test.dart';

void main() {
  group('defaultBackoff', () {
    test('returns 1 second for retryCount 0', () {
      expect(defaultBackoff(0), const Duration(seconds: 1));
    });

    test('doubles for each retry', () {
      expect(defaultBackoff(1), const Duration(seconds: 2));
      expect(defaultBackoff(2), const Duration(seconds: 4));
      expect(defaultBackoff(3), const Duration(seconds: 8));
      expect(defaultBackoff(4), const Duration(seconds: 16));
      expect(defaultBackoff(5), const Duration(seconds: 32));
      expect(defaultBackoff(6), const Duration(seconds: 64));
      expect(defaultBackoff(7), const Duration(seconds: 128));
      expect(defaultBackoff(8), const Duration(seconds: 256));
    });

    test('saturates at 5 minutes', () {
      const cap = Duration(minutes: 5);
      expect(defaultBackoff(9), cap);
      expect(defaultBackoff(10), cap);
      expect(defaultBackoff(100), cap);
    });

    test('treats negative input as 0', () {
      expect(defaultBackoff(-1), const Duration(seconds: 1));
      expect(defaultBackoff(-100), const Duration(seconds: 1));
    });
  });
}
