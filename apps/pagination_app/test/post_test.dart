import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:pagination_app/entities/post.dart';

void main() {
  test('Post.fromRow maps a synced row to an entity', () {
    final post = Post.fromRow({
      SyncColumns.id: '5',
      'userId': 2,
      'title': 'a title',
      'body': 'some body',
    });
    expect(post.id, '5');
    expect(post.userId, 2);
    expect(post.title, 'a title');
    expect(post.body, 'some body');
  });
}
