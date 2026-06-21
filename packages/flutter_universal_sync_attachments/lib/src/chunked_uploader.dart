import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when a chunk upload returns a non-success status.
class AttachmentUploadException implements Exception {
  /// Creates an exception describing a failed upload.
  AttachmentUploadException(this.message, {this.statusCode});

  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code that triggered the failure, if any.
  final int? statusCode;

  @override
  String toString() => 'AttachmentUploadException: $message'
      '${statusCode == null ? '' : ' (status $statusCode)'}';
}

/// Outcome of a single [ChunkedUploader.upload] call.
class UploadResult {
  /// Creates an upload result.
  const UploadResult({
    required this.totalBytes,
    required this.bytesSent,
    required this.chunks,
  });

  /// Total size of the attachment in bytes.
  final int totalBytes;

  /// Bytes actually transmitted by this call (excludes a resumed prefix).
  final int bytesSent;

  /// Number of chunk requests issued by this call.
  final int chunks;

  /// Whether the resumed prefix was already complete (nothing to send).
  bool get resumedComplete => bytesSent == 0 && totalBytes > 0;
}

/// Uploads a byte payload to a URL in fixed-size chunks, resuming from an
/// offset the server reports.
///
/// The protocol is intentionally generic (tus-like): each chunk is sent as an
/// HTTP `PATCH` carrying a `Content-Range: bytes <start>-<end>/<total>` header
/// and an offset header (default `upload-offset`). The server replies with the
/// new offset in that same header; if it does not, the uploader assumes the
/// chunk landed and advances locally. When [resume] is set, a probe request
/// (default `HEAD`) reads the already-received offset before sending, so an
/// interrupted upload continues where it stopped. Header names and the probe
/// method are configurable to fit other backends.
class ChunkedUploader {
  /// Creates an uploader over an injectable [client] (defaults to a new
  /// `http.Client`). [chunkSize] bytes are sent per request.
  ChunkedUploader({
    http.Client? client,
    this.chunkSize = 256 * 1024,
    this.resume = true,
    this.offsetHeader = 'upload-offset',
    this.probeMethod = 'HEAD',
  })  : _client = client ?? http.Client(),
        assert(chunkSize > 0, 'chunkSize must be positive');

  final http.Client _client;

  /// Number of bytes sent per chunk request.
  final int chunkSize;

  /// Whether to probe the server for an already-received offset before sending.
  final bool resume;

  /// Header carrying the byte offset, both probed and sent (default
  /// `upload-offset`).
  final String offsetHeader;

  /// HTTP method used for the resume probe (default `HEAD`).
  final String probeMethod;

  /// Uploads [bytes] to [url], resuming from the server offset when [resume] is
  /// set. [onProgress] receives `(uploaded, total)` after each advance.
  ///
  /// Throws [AttachmentUploadException] if a chunk request fails.
  Future<UploadResult> upload({
    required Uri url,
    required Uint8List bytes,
    String? contentType,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final total = bytes.length;
    var offset = resume ? await _probeOffset(url) : 0;
    if (offset > total) offset = total;
    final start = offset;
    onProgress?.call(offset, total);

    var chunks = 0;
    while (offset < total) {
      final end = offset + chunkSize < total ? offset + chunkSize : total;
      final chunk = Uint8List.sublistView(bytes, offset, end);
      final res = await _client.patch(
        url,
        headers: {
          'content-range': 'bytes $offset-${end - 1}/$total',
          offsetHeader: '$offset',
          if (contentType != null) 'content-type': contentType,
        },
        body: chunk,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AttachmentUploadException(
          'chunk [$offset-${end - 1}] rejected',
          statusCode: res.statusCode,
        );
      }
      // Prefer the server-reported offset; otherwise assume the chunk landed.
      offset = int.tryParse(res.headers[offsetHeader] ?? '') ?? end;
      chunks++;
      onProgress?.call(offset, total);
    }

    return UploadResult(
      totalBytes: total,
      bytesSent: total - start,
      chunks: chunks,
    );
  }

  /// Reads the already-received byte offset for [url]. Best-effort: any failure
  /// (network error, non-2xx, missing header) yields offset 0.
  Future<int> _probeOffset(Uri url) async {
    try {
      final streamed = await _client.send(http.Request(probeMethod, url));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode < 200 || res.statusCode >= 300) return 0;
      return int.tryParse(res.headers[offsetHeader] ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Closes the underlying HTTP client.
  void close() => _client.close();
}
