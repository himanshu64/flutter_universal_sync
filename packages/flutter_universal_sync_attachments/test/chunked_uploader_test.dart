import 'dart:typed_data';

import 'package:flutter_universal_sync_attachments/flutter_universal_sync_attachments.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  Uint8List bytesOf(int n) =>
      Uint8List.fromList(List.generate(n, (i) => i % 256));
  final url = Uri.parse('https://example.test/upload/1');

  test('sends sequential chunks, advancing locally with no offset header',
      () async {
    final ranges = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404); // no resume info
      ranges.add(req.headers['content-range']!);
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
    ).upload(url: url, bytes: bytesOf(10));

    expect(res.chunks, 3);
    expect(res.bytesSent, 10);
    expect(res.totalBytes, 10);
    expect(ranges, ['bytes 0-3/10', 'bytes 4-7/10', 'bytes 8-9/10']);
  });

  test('resumes from the server-reported offset', () async {
    final ranges = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'HEAD') {
        return http.Response('', 200, headers: {'upload-offset': '4'});
      }
      ranges.add(req.headers['content-range']!);
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
    ).upload(url: url, bytes: bytesOf(10));

    expect(ranges, ['bytes 4-7/10', 'bytes 8-9/10']);
    expect(res.bytesSent, 6);
    expect(res.chunks, 2);
  });

  test('does nothing when the server already has every byte', () async {
    var patches = 0;
    final client = MockClient((req) async {
      if (req.method == 'HEAD') {
        return http.Response('', 200, headers: {'upload-offset': '10'});
      }
      patches++;
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
    ).upload(url: url, bytes: bytesOf(10));

    expect(patches, 0);
    expect(res.chunks, 0);
    expect(res.bytesSent, 0);
    expect(res.resumedComplete, isTrue);
  });

  test('advances using the server-reported offset header', () async {
    final ranges = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      final range = req.headers['content-range']!;
      ranges.add(range);
      final end = int.parse(range.split('-')[1].split('/')[0]) + 1;
      return http.Response('', 200, headers: {'upload-offset': '$end'});
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
    ).upload(url: url, bytes: bytesOf(10));

    expect(res.chunks, 3);
    expect(ranges.last, 'bytes 8-9/10');
  });

  test('throws AttachmentUploadException on a rejected chunk', () async {
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      return http.Response('nope', 500);
    });
    await expectLater(
      ChunkedUploader(
        client: client,
        chunkSize: 4,
      ).upload(url: url, bytes: bytesOf(10)),
      throwsA(
        isA<AttachmentUploadException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.toString(), 'toString', contains('status 500')),
      ),
    );
  });

  test('empty payload is a no-op success', () async {
    var patches = 0;
    final client = MockClient((req) async {
      patches++;
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      resume: false,
    ).upload(url: url, bytes: Uint8List(0));

    expect(patches, 0);
    expect(res.chunks, 0);
    expect(res.resumedComplete, isFalse); // total is 0
  });

  test('skips the probe when resume is false', () async {
    var heads = 0;
    final client = MockClient((req) async {
      if (req.method == 'HEAD') {
        heads++;
        return http.Response('', 200, headers: {'upload-offset': '4'});
      }
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
      resume: false,
    ).upload(url: url, bytes: bytesOf(10));

    expect(heads, 0);
    expect(res.chunks, 3); // started at offset 0, ignoring the server offset
  });

  test('a failed probe falls back to offset 0', () async {
    final client = MockClient((req) async {
      if (req.method == 'HEAD') throw Exception('network down');
      return http.Response('', 200);
    });
    final res = await ChunkedUploader(
      client: client,
      chunkSize: 4,
    ).upload(url: url, bytes: bytesOf(8));

    expect(res.chunks, 2);
    expect(res.bytesSent, 8);
  });

  test('sends content-type and reports incremental progress', () async {
    String? contentType;
    final progress = <int>[];
    final client = MockClient((req) async {
      if (req.method == 'HEAD') return http.Response('', 404);
      contentType = req.headers['content-type'];
      return http.Response('', 200);
    });
    await ChunkedUploader(client: client, chunkSize: 4).upload(
      url: url,
      bytes: bytesOf(10),
      contentType: 'image/png',
      onProgress: (uploaded, total) => progress.add(uploaded),
    );

    expect(contentType, startsWith('image/png'));
    expect(progress, [0, 4, 8, 10]);
  });

  test('defaults to a real http client when none is injected', () {
    final uploader = ChunkedUploader();
    expect(uploader.close, returnsNormally);
  });

  test('close() releases the client', () {
    expect(
      ChunkedUploader(client: MockClient((_) async => http.Response('', 200)))
          .close,
      returnsNormally,
    );
  });
}
