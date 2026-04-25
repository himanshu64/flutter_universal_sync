import 'sync_status.dart';

/// Base class every domain entity synced by `flutter_universal_sync` extends.
///
/// Carries the six sync metadata fields required by the package. Subclasses
/// own their domain fields and provide [toMap] (and by convention a
/// `fromMap`/named constructor). Subclasses must also populate [id],
/// [createdAt], and [updatedAt] — the package does not generate them here;
/// use an [IdGenerator] to produce ids at the repository boundary.
abstract class SyncEntity {
  /// UUIDv4 identifier — client-generated at insert time, stable forever.
  String get id;

  /// Wall-clock creation time (UTC, ms precision).
  DateTime get createdAt;

  /// Wall-clock last-update time (UTC, ms precision).
  DateTime get updatedAt;

  /// `null` = live; non-null = soft-deleted at the wall-clock time given.
  /// Soft-deleted rows are never hard-removed locally; the row persists
  /// so the deletion can be communicated to every remote.
  DateTime? get deletedAt;

  /// `true` once a remote backend has acknowledged the latest change.
  bool get isSynced;

  /// Lifecycle state of the most recent sync attempt.
  SyncStatus get syncStatus;

  /// Serializes the entity, including every key in [SyncColumns.required]
  /// with correctly-typed values, plus any subclass-specific fields.
  Map<String, dynamic> toMap();
}
