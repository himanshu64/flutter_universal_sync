# Changelog

## 0.1.0 — 2026-06-21

Initial release. Supabase (PostgREST) `RemoteSyncAdapter`.

### Added
- `SupabaseSyncAdapter`: insert→`POST` (upsert via `Prefer:
  resolution=merge-duplicates`), update/delete→`PATCH ?id=eq.<id>`,
  pull→`GET ?or=(updated_at.gt,deleted_at.gt)&order=updated_at`. `apikey` +
  rotating bearer `token`. Non-2xx → `SyncPushException`/`SyncPullException`.
- `MockClient` unit tests (100% line coverage). Live verification needs a
  Supabase project.
