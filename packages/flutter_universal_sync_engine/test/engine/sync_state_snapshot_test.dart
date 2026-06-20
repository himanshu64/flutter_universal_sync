import 'package:flutter_universal_sync_engine/src/engine/engine_status.dart';
import 'package:flutter_universal_sync_engine/src/engine/sync_state_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('SyncStateSnapshot', () {
    test('idle factory has the expected shape', () {
      final s = SyncStateSnapshot.idle(pendingCount: 0);
      expect(s.status, EngineStatus.idle);
      expect(s.pendingCount, 0);
      expect(s.lastSyncedAt, isNull);
      expect(s.lastError, isNull);
    });

    test('syncing factory carries pendingCount', () {
      final s = SyncStateSnapshot.syncing(pendingCount: 3);
      expect(s.status, EngineStatus.syncing);
      expect(s.pendingCount, 3);
    });

    test('error factory carries lastError', () {
      final s = SyncStateSnapshot.error(
        pendingCount: 2,
        lastError: 'http 500',
      );
      expect(s.status, EngineStatus.error);
      expect(s.lastError, 'http 500');
    });

    test('copyWith replaces fields, preserves rest', () {
      final base = SyncStateSnapshot.idle(pendingCount: 0);
      final t = DateTime.utc(2026, 1, 1);
      final updated = base.copyWith(
        status: EngineStatus.syncing,
        pendingCount: 5,
        lastSyncedAt: t,
      );
      expect(updated.status, EngineStatus.syncing);
      expect(updated.pendingCount, 5);
      expect(updated.lastSyncedAt, t);
      expect(updated.lastError, isNull);
    });

    test('copyWith with sentinel-style nulling clears lastError', () {
      final base = SyncStateSnapshot.error(
        pendingCount: 1,
        lastError: 'old',
      );
      final cleared = base.copyWith(clearLastError: true);
      expect(cleared.lastError, isNull);
    });

    test('value equality and hashCode', () {
      final a = SyncStateSnapshot.idle(pendingCount: 0);
      final b = SyncStateSnapshot.idle(pendingCount: 0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
