# Changelog

## 0.1.0 — 2026-06-21

Initial release. Real-time server-push channel for the
`flutter_universal_sync` family.

### Added
- `RealtimeChannel` — keeps a transport-agnostic event subscription alive and
  applies incoming `RealtimeEvent`s to a `LocalDatabaseAdapter` (or a custom
  `onEvent` handler, e.g. to trigger `engine.syncNow`). Reconnects with
  exponential backoff (`defaultRealtimeBackoff`, capped at 30s), exposes a
  `RealtimeStatus` stream, and serializes async handling with backpressure. The
  transport is injected as a `Stream<RealtimeEvent>` thunk, so it is fully
  testable with plain `StreamController`s — no real socket.
- `RealtimeEvent` / `RealtimeEventType` — decoded upsert/delete row events.
