import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Simple domain entity for the demo. Mirrors the `things` table the
/// test backend exposes.
class Thing extends SyncEntity {
  Thing({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.name,
    this.deletedAt,
    this.isSynced = false,
    this.syncStatus = SyncStatus.pending,
  });

  factory Thing.fromMap(Map<String, dynamic> m) => Thing(
        id: m['id'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          m['created_at'] as int,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          m['updated_at'] as int,
          isUtc: true,
        ),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                m['deleted_at'] as int,
                isUtc: true,
              ),
        isSynced: (m['is_synced'] as int? ?? 0) == 1,
        syncStatus: SyncStatus.values.byName(
          (m['sync_status'] as String? ?? 'pending'),
        ),
        name: m['name'] as String? ?? '',
      );

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;
  @override
  final bool isSynced;
  @override
  final SyncStatus syncStatus;
  final String name;

  Thing copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isSynced,
    SyncStatus? syncStatus,
    String? name,
  }) =>
      Thing(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        isSynced: isSynced ?? this.isSynced,
        syncStatus: syncStatus ?? this.syncStatus,
        name: name ?? this.name,
      );

  @override
  Map<String, dynamic> toMap() => {
        SyncColumns.id: id,
        SyncColumns.createdAt: createdAt.toUtc().millisecondsSinceEpoch,
        SyncColumns.updatedAt: updatedAt.toUtc().millisecondsSinceEpoch,
        SyncColumns.deletedAt: deletedAt?.toUtc().millisecondsSinceEpoch,
        SyncColumns.isSynced: isSynced ? 1 : 0,
        SyncColumns.syncStatus: syncStatus.name,
        'name': name,
      };
}
