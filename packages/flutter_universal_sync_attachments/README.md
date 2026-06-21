# flutter_universal_sync_attachments

Resumable **chunked media/attachment uploads** for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. Sync engines move rows; large binaries (photos, audio, video) need a
different path — uploaded in chunks so a dropped connection resumes instead of
restarting from zero.

The HTTP client is injected, so this package is pure Dart and fully testable
with `package:http`'s `MockClient` — no network in tests.

## Install

```yaml
dependencies:
  flutter_universal_sync_attachments: ^0.1.0
```

## ChunkedUploader

```dart
import 'package:flutter_universal_sync_attachments/flutter_universal_sync_attachments.dart';

final uploader = ChunkedUploader(chunkSize: 256 * 1024); // 256 KiB chunks

final result = await uploader.upload(
  url: Uri.parse('https://api.example.com/uploads/$photoId'),
  bytes: photoBytes,            // Uint8List
  contentType: 'image/jpeg',
  onProgress: (uploaded, total) => print('$uploaded / $total'),
);
print('sent ${result.bytesSent} of ${result.totalBytes} in ${result.chunks} chunks');
```

### Wire protocol

Each chunk is an HTTP `PATCH` carrying:

| Header          | Example                  |
| --------------- | ------------------------ |
| `Content-Range` | `bytes 262144-524287/900000` |
| `upload-offset` | `262144`                 |
| `content-type`  | `image/jpeg` (if given)  |

The server replies `2xx` and **should** return the new byte offset in the
`upload-offset` response header; the uploader continues from there. If the
header is absent it assumes the chunk landed and advances locally. This mirrors
a simplified [tus](https://tus.io) flow — header names (`offsetHeader`) and the
probe method (`probeMethod`) are constructor options if your backend differs.

### Resuming an interrupted upload

With `resume: true` (the default) the uploader first probes the URL (a `HEAD`
by default) and reads `upload-offset` to learn how many bytes the server already
holds, then sends only the remainder:

```dart
// Connection dropped after 2 of 4 chunks. Calling upload again:
//   1. HEAD  → server says upload-offset: 524288
//   2. PATCH  bytes 524288-786431/900000
//   3. PATCH  bytes 786432-899999/900000
await uploader.upload(url: url, bytes: photoBytes);
```

Probing is best-effort: a network error, non-2xx, or missing header just starts
from offset 0.

## AttachmentQueue

Track many attachments and drain them together. Failures don't stop the batch —
each failed entry is marked `failed` and retried on the next `drain()`,
resuming from the server offset.

```dart
final queue = AttachmentQueue(uploader);

queue.enqueue(Attachment(
  id: photoId,                 // stable id (e.g. the owning row) — de-dupes
  url: Uri.parse('https://api.example.com/uploads/$photoId'),
  bytes: photoBytes,
  contentType: 'image/jpeg',
));

final uploaded = await queue.drain(
  onProgress: (id, uploaded, total) => print('$id: $uploaded/$total'),
);

queue.statusOf(photoId); // AttachmentStatus.uploaded | pending | failed
queue.outstanding;       // attachments not yet uploaded
```

### Pairing with the sync engine

A common pattern: sync the row optimistically (so the UI updates offline), and
enqueue its binary separately. When connectivity returns, drain both — the row
through the [sync engine](https://github.com/REPLACE_ME/flutter_universal_sync)
and the bytes through the `AttachmentQueue`. Store the attachment metadata
(id + url) in your own table if it must survive an app restart; this queue holds
bytes in memory only.

## License

MIT — see [LICENSE](LICENSE).
