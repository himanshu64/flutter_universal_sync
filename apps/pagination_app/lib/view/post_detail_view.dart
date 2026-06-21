import 'package:flutter/material.dart';

import '../entities/post.dart';

class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post ${post.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('by User ${post.userId}',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Text(post.body),
          ],
        ),
      ),
    );
  }
}
