# Battery performance — how these apps stay efficient

Battery on mobile is spent in three places: the **radio** (every network request
wakes it, with an expensive ~seconds-long tail), the **CPU** (image decode,
layout, widget rebuilds), and the **GPU** (overdraw, continuous animation). The
four sample apps — and the sync engine underneath them — are built to minimise
all three. This is both a checklist and a record of what's applied where.

## The sync engine is battery-friendly by design

Every app reads through `flutter_universal_sync`, which avoids the classic
battery sinks:

| Technique | Why it saves battery |
|---|---|
| **Offline-first reads** | The UI renders from the local Hive cache instantly. The radio is touched only to fetch *deltas*, never on the read path. |
| **Connectivity-gated sync** | The engine checks `ConnectivityMonitor.isOnline` and skips the cycle when offline — no doomed requests waking the radio. |
| **Exponential backoff** | A failed push backs off `1s → 2s → … → 5min` (`next_retry_at`), so a flaky server can't hot-loop the radio. |
| **No busy polling** | Auto-drain = a 5-min periodic timer + connectivity *transitions* + explicit `syncNow()`. No tight loop. |
| **Coalesced cycles** | Concurrent triggers share one in-flight cycle, so "mash refresh" = one network burst, not many. |
| **Write batching** | Offline edits accumulate in the queue and drain in a single cycle on reconnect — one radio wake, not one per edit. |

## Per-app techniques

### Todo · Clean Architecture
- **Local-first writes** — typing/toggling never touches the network; the push
  is one coalesced engine cycle.
- Offline edits queue and sync once on reconnect (single radio wake).
- `ListView.builder` + scoped `ListenableBuilder` rebuilds (no app-wide setState).

### Twitter timeline · MVVM
- **Cached avatars** via `cached_network_image` (memory + disk) — scrolling back
  or reopening the app costs **zero** network and zero re-decode.
- **Downsampled** avatars: `memCacheWidth: 88` decodes a 44px circle at 88px, not
  at the source resolution.
- Cache-first render: tweets show instantly from Hive, then a pull refreshes.

### Pagination · VIPER
- **On-demand paging** — 20 rows per page, fetched only when you scroll near the
  end (threshold + re-entrancy guard in the View), never up front.
- Pages are **cached locally**, so re-scrolling costs no network.
- `ListView.builder` keeps the row count irrelevant to memory.

### Image gallery · MVVM (the stress test: 100 images)
- **`GridView.builder`** builds only on-screen cells — ~9 images decoded at once,
  not 100.
- **`cached_network_image`** memory + disk cache — each image is downloaded
  **once, ever**; revisits and app restarts hit the disk cache.
- **`memCacheWidth: 300`** downsamples each thumbnail decode to cell size — a
  240px decode instead of a 900px one is ~14× less decode CPU and memory.
- The full-resolution variant is a **separate** cache entry, fetched only on tap.

## General checklist (applied across all apps)

- `const` constructors everywhere → fewer rebuilds and allocations.
- Scoped rebuilds (`ListenableBuilder` / `ChangeNotifier`) instead of
  `setState` on large subtrees.
- Lazy `ListView.builder` / `GridView.builder`, never eager `Column`/`ListView(children: …)`.
- Dispose `ScrollController`s and `StreamSubscription`s.
- Downsample + cache images (`memCacheWidth`, `cached_network_image`).
- No timers or animations running while idle.

## How to measure

- `flutter run --profile` + **DevTools → Performance / Memory** (watch frame
  build times and the image cache size).
- **Android Studio Energy Profiler** / **Xcode Energy gauge** for real draw.
- DevTools **Network** tab: scroll the gallery, scroll back — the second pass
  should show **cache hits, no new requests**. That delta is the battery win.

## Further opportunities (not yet applied)

- **Background sync** — move catch-up sync into the OS scheduler via
  `flutter_universal_sync_background` (WorkManager / BGTaskScheduler, ~15-min
  windows) instead of keeping the app awake.
- **HTTP caching** — honour `ETag` / `Cache-Control` so even cache-miss pulls are
  cheap (304s).
- **Server-side responsive images** — request WebP/AVIF at the display size.
- **Cancel offscreen image requests** and precache only a few rows ahead.
- **Adaptive cadence** — lengthen `drainInterval` (or pause sync) under OS
  battery-saver.
