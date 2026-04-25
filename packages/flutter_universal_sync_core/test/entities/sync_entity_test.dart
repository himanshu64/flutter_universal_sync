import 'package:flutter_universal_sync_core/src/entities/sync_entity.dart';
import 'package:flutter_universal_sync_core/src/entities/sync_status.dart';
import 'package:test/test.dart';

class _FakeEntity extends SyncEntity {
  _FakeEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = false, // ignore: unused_element_parameter
    this.syncStatus = SyncStatus.pending, // ignore: unused_element_parameter
    this.extra = const {},
  });

  @override final String id;
  @override final DateTime createdAt;
  @override final DateTime updatedAt;
  @override final DateTime? deletedAt;
  @override final bool isSynced;
  @override final SyncStatus syncStatus;
  final Map<String, dynamic> extra;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    'deleted_at': deletedAt?.toUtc().millisecondsSinceEpoch,
    'is_synced': isSynced ? 1 : 0,
    'sync_status': syncStatus.name,
    ...extra,
  };
}

void main() {
  group('SyncEntity', () {
    test('exposes the six sync fields via getters', () {
      final now = DateTime.utc(2026, 4, 24, 12, 0, 0);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
      );
      expect(entity.id, 'abc');
      expect(entity.createdAt, now);
      expect(entity.updatedAt, now);
      expect(entity.deletedAt, isNull);
      expect(entity.isSynced, isFalse);
      expect(entity.syncStatus, SyncStatus.pending);
    });

    test('toMap includes all sync columns plus subclass fields', () {
      final now = DateTime.utc(2026, 4, 24);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
        extra: const {'name': 'apple'},
      );
      final map = entity.toMap();
      expect(map['id'], 'abc');
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['updated_at'], now.millisecondsSinceEpoch);
      expect(map['deleted_at'], isNull);
      expect(map['is_synced'], 0);
      expect(map['sync_status'], 'pending');
      expect(map['name'], 'apple');
    });

    test('deletedAt set indicates soft delete', () {
      final now = DateTime.utc(2026, 4, 24);
      final entity = _FakeEntity(
        id: 'abc',
        createdAt: now,
        updatedAt: now,
        deletedAt: now.add(const Duration(hours: 1)),
      );
      expect(entity.deletedAt, isNotNull);
    });
  });
}
