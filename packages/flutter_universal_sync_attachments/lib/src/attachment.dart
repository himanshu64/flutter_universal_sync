import 'dart:typed_data';

/// Upload lifecycle state of an [Attachment] in an [AttachmentQueue].
enum AttachmentStatus {
  /// Not yet uploaded (also the state a failed entry returns to on retry).
  pending,

  /// Successfully uploaded.
  uploaded,

  /// The last upload attempt failed; will be retried on the next drain.
  failed,
}

/// A binary payload to be uploaded to [url].
class Attachment {
  /// Creates an attachment with a stable [id] uploaded to [url].
  Attachment({
    required this.id,
    required this.url,
    required this.bytes,
    this.contentType,
  });

  /// Stable identifier (e.g. the owning row id) used to de-duplicate uploads.
  final String id;

  /// Destination upload URL.
  final Uri url;

  /// The bytes to upload.
  final Uint8List bytes;

  /// Optional MIME type sent as `content-type` on each chunk.
  final String? contentType;
}
