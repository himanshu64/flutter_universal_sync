# Changelog

## 0.1.0 — 2026-06-21

Initial release. Resumable chunked media/attachment uploads for the
`flutter_universal_sync` family.

### Added
- `ChunkedUploader` — sends a `Uint8List` to an upload URL in fixed-size chunks
  over an injectable `http.Client`. Each chunk is an HTTP `PATCH` with a
  `Content-Range` and offset header; the uploader advances by the
  server-reported offset (or locally if absent). With `resume` set it probes the
  server (`HEAD` by default) for an already-received offset and continues from
  there. Header names and the probe method are configurable.
- `AttachmentQueue` — in-memory queue that drains attachments through the
  uploader, continuing past individual failures (failed entries retry on the
  next drain and resume from the server offset).
- `Attachment` value type and `AttachmentStatus` lifecycle enum.
