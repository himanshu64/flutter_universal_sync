# Changelog

## 0.1.0 — 2026-06-21

Initial release. CRDT conflict resolvers for the `flutter_universal_sync` family.

### Added
- `LwwMapResolver` — an LWW-Element-Map CRDT `ConflictResolver`. Per-field
  last-write-wins with embedded per-field timestamps (`_lww`); merge is
  commutative, associative, and idempotent, so replicas converge regardless of
  order. Keeps both edits when two devices change different fields. Includes a
  `stamp(row, timestamp)` helper and falls back to `updated_at` when a row has
  no per-field clock.
