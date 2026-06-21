# Offline-first challenges — what flutter_universal_sync handles

The hard problems of offline-first sync, mapped honestly against this family.
Status legend:

- ✅ **Built-in** — the packages do it.
- ⚠️ **Partial / by convention** — supported with caveats or via a documented pattern.
- 🧩 **Your app** — the family gives you the hooks; the policy is yours.
- 🗺️ **Roadmap** — not yet; a known gap.

---

## 1. Data synchronization complexity
| Concern | Status | How |
|---|---|---|
| Sync local ↔ server | ✅ | `SyncEngine` drains a per-op queue (push) and pulls deltas via a `since` cursor. |
| Intermittent connectivity | ✅ | `ConnectivityMonitor`-gated cycles + exponential backoff; offline writes queue and drain on reconnect. |
| Consistency across devices | ⚠️ | Eventual consistency via push + pull + conflict resolver. No real-time guarantee. |
| Strategy: LWW / versioning | ✅ | `LastWriteWinsResolver` (+ server/client priority); `updated_at` watermark cursor. |
| Strategy: OT / CRDT | 🗺️ | Not implemented — pluggable `ConflictResolver` instead. A CRDT resolver could be added behind the same interface. |

## 2. Conflict resolution
| Concern | Status | How |
|---|---|---|
| Same record edited in two places | ✅ | Resolver fires **only** when a pulled row collides with a local *pending* edit (spec §7), then the merged result is re-queued. |
| Last-write-wins | ✅ | `LastWriteWinsResolver`. |
| Field merge | 🧩 | Write a `ConflictResolver` that merges fields — the interface hands you `(local, remote)`. |
| User-assisted | 🧩 | A resolver can stash both versions and surface a UI; the engine just calls `resolve(local, remote)`. |
| Push-side (409) conflicts | ⚠️ | Surfaces as `SyncPushException` + retry; no push-side resolver in v1. |

## 3. Queue management
| Concern | Status | How |
|---|---|---|
| Store & replay offline actions | ✅ | `SyncQueueEntry` rows persisted in the local adapter (`sync_queue`). |
| Retry engine | ✅ | Failed pushes get `retry_count` + `next_retry_at` (backoff); the drain skips not-yet-due entries. |
| Failed retries / ordering | ✅ | Per-entity FIFO; a group stops on first failure and resumes next cycle. |
| Duplicate requests | ⚠️ | Push + mark-synced aren't one transaction, so a crash can re-push — relies on idempotent server ops (documented trade-off). No `Idempotency-Key` header yet (🗺️). |

## 4. Temporary IDs
| Concern | Status | How |
|---|---|---|
| Offline records need an id | ✅ | The **client** generates the canonical id (`UuidV4Generator`) at creation — the id never changes, so no `temp_123 → 45892` remap and no broken relationships. |
| Server-assigned ids | 🧩 | If your backend *insists* on assigning ids, keep the client UUID as the key and store the server id as a field (the model favours client-owned ids). |

## 5. Data consistency
| Concern | Status | How |
|---|---|---|
| Stale reads | ⚠️ | Reads come from the local cache (fast, offline) and converge on pull. Per-row `is_synced` / `sync_status` expose freshness. |
| Overselling / double-booking | 🧩 | Invariant enforcement (stock checks) is server-authoritative; the engine surfaces conflicts, your domain decides. |

## 6. Pagination
| Concern | Status | How |
|---|---|---|
| Local pagination + cache | ⚠️ | Shown end-to-end in [`apps/pagination_app`](apps/pagination_app/) (VIPER): server pages fetched on demand via the REST adapter, cached locally, lazy-rendered. Not a package primitive. |
| Missing pages / sort / cache size | 🧩 | App policy; the local adapter is the cache, the remote adapter the source. |

## 7. Large storage / media
| Concern | Status | How |
|---|---|---|
| Cache eviction / compression / cleanup | 🗺️ | No built-in eviction. Use your adapter's store TTL/limits. |
| Attachments & media (photo/video upload, chunking, resume) | 🗺️ | Out of scope — the engine syncs **structured rows**, not binaries. Image *caching* is demonstrated in [`apps/image_gallery`](apps/image_gallery/) via `cached_network_image`. |

## 8. Background sync
| Concern | Status | How |
|---|---|---|
| OS-scheduled catch-up sync | ✅ | `flutter_universal_sync_background` — `BackgroundSyncCoordinator` rebuilds the engine in a headless isolate; WorkManager/BGTaskScheduler wiring documented. |
| OS killing jobs / battery limits | ⚠️ | Inherent to the platforms; the coordinator returns success/failure for the OS retry policy. |

## 9. Network state detection
| Concern | Status | How |
|---|---|---|
| Connected vs reachable vs authenticated vs syncable | ⚠️ | The engine only needs a boolean `ConnectivityMonitor.isOnline` — **you** decide what "online" means (a heartbeat to your API, captive-portal/VPN/DNS checks, auth state). The `connectivity_plus` reference is connectivity-only. |

## 10. Duplicate requests / idempotency
| Concern | Status | How |
|---|---|---|
| Triple-tap submit | ⚠️ | One enqueue per mutation; the queue de-dupes by intent. Cross-restart re-push relies on idempotent server writes. |
| Idempotency keys | 🗺️ | The queue-entry id is a natural key; sending it as an `Idempotency-Key` header is a small adapter addition. |

## 11. Ordering dependencies
| Concern | Status | How |
|---|---|---|
| Replay order (create → task → delete) | ⚠️ | **Per-entity** order is preserved (causal). Cross-entity is serial by `created_at`; no FK-aware transaction grouping (🗺️). |

## 12. Schema migration
| Concern | Status | How |
|---|---|---|
| Local DB migration | ⚠️ | SQL adapters use the engine's versioned tables (`onUpgrade` in the sqflite/drift demos). App-data migrations (e.g. `name → firstName/lastName`) are 🧩 your responsibility. |

## 13. Security
| Concern | Status | How |
|---|---|---|
| Encrypted DB / secure keys / token expiry | 🗺️ | Not built-in. Pair a local adapter with SQLCipher / encrypted Hive box + Keychain/Keystore; the adapter interface doesn't prevent it. |

## 14. Offline authentication
| Concern | Status | How |
|---|---|---|
| JWT expiry while offline / refresh | ⚠️ | Remote adapters read auth via a **per-request token callback**, so a refreshed token is picked up without rebuilding. The refresh/grace-period strategy is 🧩 yours. |

## 15. Eventual consistency & status UI
| Concern | Status | How |
|---|---|---|
| "Saved" but sync pending/failed | ✅ | `Stream<SyncStateSnapshot>` (`idle`/`syncing`/`error`, `pendingCount`, `lastError`) + per-row `sync_status` — bind it to badges (shown in every sample app). |

## 16. Error handling
| Concern | Status | How |
|---|---|---|
| Timeout / partial / validation / conflict | ✅ | Typed `SyncException` hierarchy; the cycle never throws — errors land in `lastError` and per-entry `last_error`, and retry on the next trigger. |
| States: pending/syncing/synced/failed/retrying | ✅ | Coarse via `EngineStatus`; per-entry via `sync_status` + `retry_count`. |

## 17. Testing
| Concern | Status | How |
|---|---|---|
| Airplane mode / slow net / killed mid-sync / corruption / multi-device | ✅ | `FakeConnectivityMonitor`, `FakeRemoteSyncAdapter`, `FakeClock`, `InMemoryAdapter`, and the shared `runLocalDatabaseAdapterContract` suite make these deterministic. Engine is 100% line-covered. |

## 18. Battery
| Concern | Status | How |
|---|---|---|
| Backoff / batch / differential sync | ✅ | Exponential backoff, connectivity-gating, delta pull (cursor), no polling. See [apps/BATTERY_PERFORMANCE.md](apps/BATTERY_PERFORMANCE.md). |

## 19. Real-time + offline
| Concern | Status | How |
|---|---|---|
| WebSocket + local DB + background | 🗺️ | No real-time channel in v1 (engine is push/pull). A WS adapter could feed `pullChanges`-style updates into the same pipeline. |

## Stack coverage
- **Local adapters:** ✅ sqflite, drift, hive (contract-verified); ⚠️ objectbox (reference skeleton). Isar — 🧩 implement `LocalDatabaseAdapter` (Realm/WatermelonDB are RN-only).
- **Remote adapters:** ✅ REST, Supabase, Appwrite, GraphQL, Firebase (Firestore REST). PowerSync / ElectricSQL / Couchbase Lite — 🗺️ would each be a new `RemoteSyncAdapter`.
- **Background:** ✅ WorkManager / BGTaskScheduler via `flutter_universal_sync_background`.

---

**Summary:** the family owns the *sync runtime* — queue, retry/backoff, pull+conflict
resolution, observable state, pluggable storage/remotes, background scheduling,
and a deterministic test surface. It deliberately leaves *policy* to you (reachability
semantics, encryption, media, eviction, data migrations) and flags real gaps
(CRDT/OT, idempotency headers, FK-aware ordering, real-time) behind stable
interfaces so they can be added without breaking changes.
