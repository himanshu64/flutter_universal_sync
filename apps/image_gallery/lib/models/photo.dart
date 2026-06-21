import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Model derived from a synced `photos` row. jsonplaceholder's own image
/// URLs are dead, so we derive a stable, working image from the row id via
/// Lorem Picsum (deterministic per id → great for cache demos).
class Photo {
  const Photo({
    required this.id,
    required this.title,
    required this.thumbUrl,
    required this.fullUrl,
  });

  final String id;
  final String title;
  final String thumbUrl;
  final String fullUrl;

  factory Photo.fromRow(Map<String, dynamic> row) {
    final id = '${row[SyncColumns.id] ?? row['id'] ?? ''}';
    return Photo(
      id: id,
      title: (row['title'] ?? 'Photo $id') as String,
      thumbUrl: 'https://picsum.photos/seed/p$id/240/240',
      fullUrl: 'https://picsum.photos/seed/p$id/900/900',
    );
  }
}
