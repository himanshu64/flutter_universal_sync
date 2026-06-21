import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:test/test.dart';

void main() {
  group('flutter_universal_sync_core barrel', () {
    test('exports every public type', () {
      // Compile-time check: every symbol below must be importable via
      // the barrel alone. If a symbol is missing, this file won't compile.
      expect(SyncOperation.insert, isNotNull);
      expect(SyncStatus.pending, isNotNull);
      expect(SyncColumns.id, 'id');
      expect(UuidV4Generator().nextId(), isNotEmpty);
      expect(const LastWriteWinsResolver(), isA<ConflictResolver>());
      expect(const ServerPriorityResolver(), isA<ConflictResolver>());
      expect(const ClientPriorityResolver(), isA<ConflictResolver>());

      // Type-reference checks — force the identifiers to be linked.
      const ignoreLocal = <Type>[
        SyncEntity,
        SyncQueueEntry,
        LocalDatabaseAdapter,
        RemoteSyncAdapter,
        SyncException,
        SchemaValidationException,
        SyncPushException,
        SyncPullException,
        ConflictResolutionException,
        IdGenerator,
      ];
      expect(ignoreLocal, hasLength(10));
    });
  });
}
