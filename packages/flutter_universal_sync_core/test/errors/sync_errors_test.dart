import 'package:flutter_universal_sync_core/src/errors/sync_errors.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaValidationException', () {
    test('formats message with table name and missing columns', () {
      final ex = SchemaValidationException(
        table: 'products',
        missingColumns: ['deleted_at', 'sync_status'],
      );
      expect(
        ex.message,
        equals('Table products is missing sync columns: '
            'deleted_at, sync_status'),
      );
      expect(ex.toString(), equals('SchemaValidationException: ${ex.message}'));
    });

    test('is a SyncException', () {
      expect(
        SchemaValidationException(table: 't', missingColumns: const ['x']),
        isA<SyncException>(),
      );
    });
  });

  group('SyncPushException', () {
    test('wraps the underlying cause', () {
      final cause = StateError('500');
      final ex = SyncPushException(queueEntryId: 'q1', cause: cause);
      expect(ex.queueEntryId, 'q1');
      expect(ex.cause, same(cause));
      expect(ex.message, contains('q1'));
      expect(ex.message, contains('500'));
    });
  });

  group('SyncPullException', () {
    test('includes table name in message', () {
      final ex = SyncPullException(table: 'orders', cause: 'timeout');
      expect(ex.message, contains('orders'));
      expect(ex.message, contains('timeout'));
    });
  });

  group('ConflictResolutionException', () {
    test('includes entity id in message', () {
      final ex = ConflictResolutionException(
        entityId: 'e42',
        cause: Exception('resolver bug'),
      );
      expect(ex.entityId, 'e42');
      expect(ex.message, contains('e42'));
    });
  });
}
