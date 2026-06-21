import 'dart:typed_data';

import 'package:flutter_universal_sync_attachments/flutter_universal_sync_attachments.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  Uint8List bytesOf(int n) =>
      Uint8List.fromList(List.generate(n, (i) => i % 256));

  Attachment att(String id, int n) => Attachment(
        id: id,
        url: Uri.parse('https://example.test/$id'),
        bytes: bytesOf(n),
      );

  test('drains pending attachments and counts uploads', () async {
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      return http.Response('', 200);
    });
    final queue =
        AttachmentQueue(ChunkedUploader(client: client, chunkSize: 4));
    queue.enqueue(att('a', 6));
    queue.enqueue(att('b', 2));

    expect(await queue.drain(), 2);
    expect(queue.statusOf('a'), AttachmentStatus.uploaded);
    expect(queue.statusOf('b'), AttachmentStatus.uploaded);
    expect(queue.outstanding, isEmpty);
  });

  test('records failures and retries them on the next drain', () async {
    var failB = true;
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      if (req.url.path == '/b' && failB) return http.Response('', 500);
      return http.Response('', 200);
    });
    final queue =
        AttachmentQueue(ChunkedUploader(client: client, chunkSize: 4));
    queue.enqueue(att('a', 4));
    queue.enqueue(att('b', 4));

    expect(await queue.drain(), 1);
    expect(queue.statusOf('a'), AttachmentStatus.uploaded);
    expect(queue.statusOf('b'), AttachmentStatus.failed);
    expect(queue.errorOf('b'), contains('500'));
    expect(queue.outstanding.map((a) => a.id), ['b']);

    failB = false; // server recovers
    expect(await queue.drain(), 1); // only b retried; a is skipped
    expect(queue.statusOf('b'), AttachmentStatus.uploaded);
    expect(queue.errorOf('b'), isNull);
    expect(queue.outstanding, isEmpty);
  });

  test('forwards progress tagged with the attachment id', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      return http.Response('', 200);
    });
    final queue =
        AttachmentQueue(ChunkedUploader(client: client, chunkSize: 4));
    queue.enqueue(att('a', 4));

    await queue.drain(onProgress: (id, u, t) => seen.add('$id:$u/$t'));
    expect(seen, contains('a:4/4'));
  });

  test('enqueue replaces an existing entry of the same id', () async {
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      return http.Response('', 200);
    });
    final queue =
        AttachmentQueue(ChunkedUploader(client: client, chunkSize: 4));
    queue.enqueue(att('a', 4));
    await queue.drain();
    expect(queue.statusOf('a'), AttachmentStatus.uploaded);

    queue.enqueue(att('a', 8)); // re-enqueue → back to pending
    expect(queue.statusOf('a'), AttachmentStatus.pending);
    expect(queue.outstanding.map((a) => a.id), ['a']);
  });

  test('status/error are null for unknown ids', () {
    final queue = AttachmentQueue(
      ChunkedUploader(client: MockClient((_) async => http.Response('', 200))),
    );
    expect(queue.statusOf('nope'), isNull);
    expect(queue.errorOf('nope'), isNull);
  });
}
