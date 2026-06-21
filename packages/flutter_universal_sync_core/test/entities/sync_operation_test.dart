import 'package:flutter_universal_sync_core/src/entities/sync_operation.dart';
import 'package:test/test.dart';

void main() {
  group('SyncOperation', () {
    test('exposes exactly three values in declaration order', () {
      expect(
        SyncOperation.values,
        equals([
          SyncOperation.insert,
          SyncOperation.update,
          SyncOperation.delete,
        ]),
      );
    });

    test('name strings are stable (used for queue persistence)', () {
      expect(SyncOperation.insert.name, equals('insert'));
      expect(SyncOperation.update.name, equals('update'));
      expect(SyncOperation.delete.name, equals('delete'));
    });

    test('byName parses the canonical names', () {
      expect(SyncOperation.values.byName('insert'), SyncOperation.insert);
      expect(SyncOperation.values.byName('update'), SyncOperation.update);
      expect(SyncOperation.values.byName('delete'), SyncOperation.delete);
    });
  });
}
