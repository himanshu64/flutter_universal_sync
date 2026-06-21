import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:twitter_timeline/models/tweet.dart';

void main() {
  test('Tweet.fromRow maps a synced post row to a view model', () {
    final tweet = Tweet.fromRow({
      SyncColumns.id: '7',
      'userId': 3,
      'title': 'hello',
      'body': 'world',
    });
    expect(tweet.id, '7');
    expect(tweet.author, 'User 3');
    expect(tweet.handle, '@user3');
    expect(tweet.text, contains('hello'));
    expect(tweet.text, contains('world'));
    expect(tweet.avatarUrl, contains('u3'));
  });
}
