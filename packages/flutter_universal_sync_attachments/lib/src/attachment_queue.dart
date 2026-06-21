import 'attachment.dart';
import 'chunked_uploader.dart';

class _Entry {
  _Entry(this.attachment);
  final Attachment attachment;
  AttachmentStatus status = AttachmentStatus.pending;
  String? error;
}

/// An in-memory queue of [Attachment]s drained through a [ChunkedUploader].
///
/// [drain] uploads every not-yet-uploaded entry, continuing past individual
/// failures (a failed entry is marked [AttachmentStatus.failed] and retried on
/// the next drain — the uploader resumes it from the server offset). Persist
/// the attachment metadata yourself if it must survive a restart; this queue
/// holds bytes in memory.
class AttachmentQueue {
  /// Creates a queue that uploads through [uploader].
  AttachmentQueue(this.uploader);

  /// Uploader used to transmit each attachment.
  final ChunkedUploader uploader;

  final Map<String, _Entry> _entries = {};

  /// Adds (or replaces) [attachment] in the queue as pending.
  void enqueue(Attachment attachment) {
    _entries[attachment.id] = _Entry(attachment);
  }

  /// Current status of the attachment with [id], or `null` if unknown.
  AttachmentStatus? statusOf(String id) => _entries[id]?.status;

  /// Last error recorded for the attachment with [id], or `null`.
  String? errorOf(String id) => _entries[id]?.error;

  /// Attachments not yet uploaded (pending or failed).
  Iterable<Attachment> get outstanding => _entries.values
      .where((e) => e.status != AttachmentStatus.uploaded)
      .map((e) => e.attachment);

  /// Uploads every outstanding attachment, returning the count uploaded this
  /// pass. [onProgress] receives `(id, uploaded, total)` during transfer.
  Future<int> drain({
    void Function(String id, int uploaded, int total)? onProgress,
  }) async {
    var uploaded = 0;
    for (final entry in _entries.values.toList()) {
      if (entry.status == AttachmentStatus.uploaded) continue;
      final a = entry.attachment;
      try {
        await uploader.upload(
          url: a.url,
          bytes: a.bytes,
          contentType: a.contentType,
          onProgress: onProgress == null
              ? null
              : (sent, total) => onProgress(a.id, sent, total),
        );
        entry.status = AttachmentStatus.uploaded;
        entry.error = null;
        uploaded++;
      } catch (err) {
        // Cross-item continuation: record and move on to the next attachment.
        entry.status = AttachmentStatus.failed;
        entry.error = err.toString();
      }
    }
    return uploaded;
  }
}
