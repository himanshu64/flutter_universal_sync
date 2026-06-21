import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// The Model — a view-friendly shape derived from a synced `posts` row
/// (jsonplaceholder posts stand in for tweets).
class Tweet {
  const Tweet({
    required this.id,
    required this.author,
    required this.handle,
    required this.text,
    required this.avatarUrl,
  });

  final String id;
  final String author;
  final String handle;
  final String text;
  final String avatarUrl;

  factory Tweet.fromRow(Map<String, dynamic> row) {
    final userId = row['userId'] ?? 0;
    final id = '${row[SyncColumns.id] ?? row['id'] ?? ''}';
    final title = (row['title'] ?? '') as String;
    final body = (row['body'] ?? '') as String;
    return Tweet(
      id: id,
      author: 'User $userId',
      handle: '@user$userId',
      text: body.isEmpty ? title : '$title\n\n$body',
      // Stable per-user image → exercises the image cache nicely.
      avatarUrl: 'https://picsum.photos/seed/u$userId/100/100',
    );
  }
}
