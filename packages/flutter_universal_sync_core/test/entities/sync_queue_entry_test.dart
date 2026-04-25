import 'package:flutter_universal_sync_core/src/entities/sync_operation.dart';
import 'package:flutter_universal_sync_core/src/entities/sync_queue_entry.dart';
import 'package:test/test.dart';

void main() {
  group('SyncQueueEntry', () {
    final createdAt = DateTime.utc(2026, 4, 24, 10, 0, 0);

    SyncQueueEntry make({
      String id = 'q1',
      String table = 'products',
      String entityId = 'p1',
      SyncOperation operation = SyncOperation.insert,
      Map<String, dynamic> payload = const {'name': 'apple'},
      int retryCount = 0,
      String? lastError,
      bool synced = false,
    }) =>
        SyncQueueEntry(
          id: id,
          table: table,
          entityId: entityId,
          operation: operation,
          payload: payload,
          createdAt: createdAt,
          retryCount: retryCount,
          lastError: lastError,
          synced: synced,
        );

    test('constructor applies documented defaults', () {
      final entry = SyncQueueEntry(
        id: 'q1',
        table: 'products',
        entityId: 'p1',
        operation: SyncOperation.insert,
        payload: const {'name': 'apple'},
        createdAt: createdAt,
      );
      expect(entry.retryCount, 0);
      expect(entry.lastError, isNull);
      expect(entry.synced, isFalse);
    });

    test('copyWith replaces only the provided fields', () {
      final original = make();
      final copy = original.copyWith(synced: true, lastError: 'boom');
      expect(copy.id, original.id);
      expect(copy.table, original.table);
      expect(copy.entityId, original.entityId);
      expect(copy.operation, original.operation);
      expect(copy.payload, original.payload);
      expect(copy.createdAt, original.createdAt);
      expect(copy.retryCount, original.retryCount);
      expect(copy.synced, isTrue);
      expect(copy.lastError, 'boom');
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      final original = make(
        retryCount: 2,
        lastError: 'prev attempt failed',
        synced: true,
      );
      final reconstructed = SyncQueueEntry.fromMap(original.toMap());
      expect(reconstructed, equals(original));
    });

    test('toMap serialises operation as name and createdAt as millis', () {
      final entry = make(operation: SyncOperation.update);
      final map = entry.toMap();
      expect(map['operation'], 'update');
      expect(map['created_at'], createdAt.millisecondsSinceEpoch);
      expect(map['synced'], 0);
    });

    test('equality and hashCode are field-based', () {
      expect(make(), equals(make()));
      expect(make().hashCode, equals(make().hashCode));
      expect(make(), isNot(equals(make(id: 'different'))));
    });

    test('hashCode is consistent with equality for reordered payload keys', () {
      final a = make(payload: const {'x': 1, 'y': 2});
      final b = make(payload: const {'y': 2, 'x': 1});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('entries differing only in payload are not equal', () {
      expect(
        make(payload: const {'name': 'apple'}),
        isNot(equals(make(payload: const {'name': 'pear'}))),
      );
    });

    test('copyWith with lastError: null clears the field', () {
      final original = make(lastError: 'boom');
      expect(original.lastError, 'boom');
      final cleared = original.copyWith(lastError: null);
      expect(cleared.lastError, isNull);
    });

    test('copyWith without lastError preserves the existing value', () {
      final original = make(lastError: 'boom');
      final preserved = original.copyWith(synced: true);
      expect(preserved.lastError, 'boom');
    });

    test('fromMap throws ArgumentError for non-Map payload', () {
      final entry = make();
      final map = entry.toMap()..['payload'] = 'serialized json string';
      expect(
        () => SyncQueueEntry.fromMap(map),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
