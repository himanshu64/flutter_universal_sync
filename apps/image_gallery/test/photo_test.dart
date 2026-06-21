import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:image_gallery/models/photo.dart';

void main() {
  test('Photo.fromRow derives a working image URL from the row id', () {
    final photo = Photo.fromRow({SyncColumns.id: '9', 'title': 'sunset'});
    expect(photo.id, '9');
    expect(photo.title, 'sunset');
    expect(photo.thumbUrl, contains('picsum.photos'));
    expect(photo.thumbUrl, contains('p9'));
    expect(photo.fullUrl, contains('p9'));
  });
}
