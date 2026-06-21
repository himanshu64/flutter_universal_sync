/// Resumable chunked media/attachment uploads for the `flutter_universal_sync`
/// family.
///
/// - [ChunkedUploader] streams a `Uint8List` to an upload URL in chunks over an
///   injectable `http.Client`, resuming from a server-reported offset.
/// - [AttachmentQueue] tracks attachments and drains them through the uploader,
///   continuing past individual failures.
library;

export 'src/attachment.dart';
export 'src/attachment_queue.dart';
export 'src/chunked_uploader.dart';
