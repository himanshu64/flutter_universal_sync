import 'package:flutter_universal_sync_core/src/entities/sync_status.dart';
import 'package:test/test.dart';

void main() {
  group('SyncStatus', () {
    test('exposes four values in declaration order', () {
      expect(
        SyncStatus.values,
        equals([
          SyncStatus.pending,
          SyncStatus.syncing,
          SyncStatus.synced,
          SyncStatus.failed,
        ]),
      );
    });

    test('name strings are stable (used for row persistence)', () {
      expect(SyncStatus.pending.name, equals('pending'));
      expect(SyncStatus.syncing.name, equals('syncing'));
      expect(SyncStatus.synced.name, equals('synced'));
      expect(SyncStatus.failed.name, equals('failed'));
    });
  });
}
