# Remote Adapter Family — Design Spec (Plans 8–12)

> **Status:** design + skeletons. Plan 12 (REST) is shipped and verified.
> Plans 8–11 (Firebase, Supabase, Appwrite, GraphQL) ship as mock-tested
> skeletons here; live verification needs each backend's credentials.
> **Predecessor:** [engine design](./2026-04-30-sync-engine-design.md).

## 1. What a remote adapter must do

Every remote adapter implements the core `RemoteSyncAdapter` contract:

```dart
abstract class RemoteSyncAdapter {
  Future<void> pushChange(SyncQueueEntry entry);                       // one op
  Future<List<Map<String, dynamic>>> pullChanges(String table, DateTime? since);
}
```

- **push** maps one queue entry (insert/update/delete + payload) to a backend
  write. Throws `SyncPushException` on any failure; the engine retries with
  backoff.
- **pull** fetches rows for `table` changed since the cursor and returns them as
  plain maps. Throws `SyncPullException` on failure. Implementations should
  filter on `updated_at > since OR deleted_at > since` so soft-deletes
  propagate, and paginate internally.

The engine is backend-agnostic — it only ever sees these two methods, so all
four adapters below are drop-in interchangeable.

## 2. Shared concerns

| Concern | Approach |
|---|---|
| **Auth** | Each adapter takes a `headers`/`token` callback re-read per request, so rotating tokens work without reconstructing the adapter. |
| **Testability** | HTTP-based adapters (Supabase, Appwrite, Firebase REST, GraphQL) take an injectable `http.Client`, unit-tested with `package:http/testing`'s `MockClient`. |
| **Soft delete** | `delete` is a write that sets `deleted_at` (or the backend's tombstone), never a hard delete, so peers can pull the tombstone. |
| **Conflicts** | v1 is pull-side only (engine §7). A push 409/precondition-failure surfaces as `SyncPushException` and retries; no push-side resolver. |
| **Pagination** | `pullChanges` returns the full delta; adapters loop internal pages until exhausted before returning. |

## 3. Plan 8 — Firebase (Cloud Firestore)

- **Transport:** Firestore REST API (`https://firestore.googleapis.com/v1/projects/<p>/databases/(default)/documents`) so the adapter stays pure-Dart; a Flutter app can alternatively wrap the `cloud_firestore` SDK behind the same interface.
- **push:** insert/update → `PATCH .../<table>/<id>` with a Firestore-typed document body (`{fields: {name: {stringValue: ...}}}`); delete → soft-delete `PATCH` setting `deleted_at`, or `DELETE .../<table>/<id>` for hard delete.
- **pull:** `runQuery` with a `structuredQuery` filtering `updated_at > since`, ordered by `updated_at`, paged by cursor. Decode Firestore-typed fields back to plain JSON.
- **Limitations (skeleton):** the typed-field encode/decode is the bulk of the work and is stubbed with a `_encodeFields`/`_decodeFields` pair; live verification needs a Firebase project + ID token.

## 4. Plan 9 — Supabase (PostgREST)

- **Transport:** Supabase's PostgREST endpoint (`<url>/rest/v1/<table>`) + the `apikey`/`Authorization` headers. The cleanest of the four — PostgREST is plain JSON over HTTP.
- **push:** insert → `POST /rest/v1/<table>` with `Prefer: resolution=merge-duplicates` (upsert); update → `PATCH /rest/v1/<table>?id=eq.<id>`; delete → soft-delete `PATCH` setting `deleted_at`.
- **pull:** `GET /rest/v1/<table>?or=(updated_at.gt.<since>,deleted_at.gt.<since>)&order=updated_at`. Range header for pagination.
- **Verifiable** against a free Supabase project; skeleton ships mock-tested.

## 5. Plan 10 — GraphQL (tested against the SpaceX API)

- **Transport:** a single `POST <endpoint>` with `{query, variables}`; this skeleton is wired to `https://spacex-production.up.railway.app/` (read-only) for live pull tests.
- **pull:** a configurable query per table returning a list; the SpaceX skeleton queries `launches`. Maps the GraphQL list to row maps.
- **push:** a configurable mutation per operation. SpaceX is **read-only**, so push is exercised with `MockClient` only; real backends supply insert/update/delete mutations.
- **Live pull** is verified against SpaceX in an integration test (`dart test -t integration`).

## 6. Plan 11 — Appwrite (Databases API)

- **Transport:** Appwrite REST (`<endpoint>/databases/<db>/collections/<table>/documents`) + `X-Appwrite-Project` / `X-Appwrite-Key` headers.
- **push:** insert → `POST .../documents` (`{documentId, data}`); update → `PATCH .../documents/<id>`; delete → soft-delete `PATCH`, or `DELETE .../documents/<id>`.
- **pull:** `GET .../documents?queries[]=greaterThan("updated_at", <since>)`; Appwrite wraps results in `{documents: [...]}` — unwrapped to row maps.
- Skeleton ships mock-tested; live verification needs an Appwrite project.

## 7. Testing & status

| Plan | Package | Unit (mock) | Live |
|---|---|---|---|
| 12 | rest | ✅ shipped | ✅ jsonplaceholder |
| 9 | supabase | ✅ mock | needs project |
| 11 | appwrite | ✅ mock | needs project |
| 10 | graphql | ✅ mock | ✅ SpaceX (pull) |
| 8 | firebase | ✅ mock (skeleton) | needs project + typed-field work |

Each skeleton is a real package (pubspec, adapter, mock tests, README, CI) that
a downstream user finishes by supplying credentials and, for Firebase, the
Firestore typed-field codec.
