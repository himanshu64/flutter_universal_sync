import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:test/test.dart';

void main() {
  group('rowFreshness', () {
    test('synced by is_synced flag or sync_status', () {
      expect(
        rowFreshness({SyncColumns.isSynced: 1}),
        RowFreshness.synced,
      );
      expect(
        rowFreshness({SyncColumns.syncStatus: 'synced'}),
        RowFreshness.synced,
      );
    });

    test('pending otherwise', () {
      expect(
        rowFreshness(const {
          SyncColumns.isSynced: 0,
          SyncColumns.syncStatus: 'pending',
        }),
        RowFreshness.pending,
      );
      expect(rowFreshness(const {}), RowFreshness.pending);
    });
  });

  group('StalenessPolicy', () {
    const policy = StalenessPolicy(Duration(minutes: 5));
    final now = DateTime.utc(2026, 1, 1, 12);

    test('fresh within maxAge', () {
      expect(
        policy.isStale(now.subtract(const Duration(minutes: 1)), now),
        isFalse,
      );
    });

    test('stale beyond maxAge', () {
      expect(
        policy.isStale(now.subtract(const Duration(minutes: 10)), now),
        isTrue,
      );
    });

    test('never-synced is always stale', () {
      expect(policy.isStale(null, now), isTrue);
    });
  });
}
