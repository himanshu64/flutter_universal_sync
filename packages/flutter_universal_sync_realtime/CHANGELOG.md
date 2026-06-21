# Changelog

## 0.1.1 — 2026-06-21

### Added
- `monotonic` (default `true`) on `RealtimeChannel` — the auto-apply path skips
  an incoming row whose `updated_at` is not newer than the local copy, so
  out-of-order server-push delivery can never regress a device to an older
  version (a monotonic-reads guarantee for cross-device consistency). Set
  `monotonic: false` to restore blind last-message-wins apply.
- `onApplied` hook — invoked after an event is applied (e.g. to call
  `engine.syncNow()` so the device also flushes its own pending writes and fully
  converges). Not fired for a monotonic skip.

### Testing
- Live integration test against `wss://echo.websocket.org` (a real WebSocket
  round-trip), tagged `integration` and excluded from the default/coverage run.

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
