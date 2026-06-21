import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// VIPER Entity — a plain post (jsonplaceholder `/posts`).
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  final String id;
  final int userId;
  final String title;
  final String body;

  factory Post.fromRow(Map<String, dynamic> row) => Post(
        id: '${row[SyncColumns.id] ?? row['id'] ?? ''}',
        userId: row['userId'] is int
            ? row['userId'] as int
            : int.tryParse('${row['userId']}') ?? 0,
        title: (row['title'] ?? '') as String,
        body: (row['body'] ?? '') as String,
      );
}
