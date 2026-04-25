import 'package:flutter_universal_sync_core/src/schema/sync_columns.dart';
import 'package:test/test.dart';

void main() {
  group('SyncColumns', () {
    test('required list contains the six canonical column names', () {
      expect(SyncColumns.required, [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_synced',
        'sync_status',
      ]);
    });

    test('individual constants match the list', () {
      expect(SyncColumns.id, 'id');
      expect(SyncColumns.createdAt, 'created_at');
      expect(SyncColumns.updatedAt, 'updated_at');
      expect(SyncColumns.deletedAt, 'deleted_at');
      expect(SyncColumns.isSynced, 'is_synced');
      expect(SyncColumns.syncStatus, 'sync_status');
    });

    test('types map covers every required column', () {
      for (final col in SyncColumns.required) {
        expect(SyncColumns.types.containsKey(col), isTrue,
            reason: '$col missing from types map',
        );
      }
    });

    test('types for createdAt/updatedAt are INTEGER NOT NULL', () {
      expect(SyncColumns.types[SyncColumns.createdAt], 'INTEGER NOT NULL');
      expect(SyncColumns.types[SyncColumns.updatedAt], 'INTEGER NOT NULL');
    });

    test('deleted_at type is nullable INTEGER', () {
      expect(SyncColumns.types[SyncColumns.deletedAt], 'INTEGER');
    });
  });
}
