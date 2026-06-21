# Sample apps

Four runnable Flutter apps, each demonstrating a **different architecture** on
the **same `flutter_universal_sync` stack** (`SyncEngine` / `HiveSyncAdapter` /
`RestSyncAdapter`) against the public `jsonplaceholder` API. All are offline-first
and battery-conscious — see [BATTERY_PERFORMANCE.md](BATTERY_PERFORMANCE.md).

| App | Architecture | What it shows |
|---|---|---|
| [`todo_app`](todo_app/) | **Clean Architecture** (domain / data / presentation, use cases) | Offline-first CRUD: optimistic writes, operation queue, retry/backoff, offline→online resync via the full `SyncEngine`. |
| [`twitter_timeline`](twitter_timeline/) | **MVVM** (Model / ViewModel / View) | Cache-first feed; pull to refresh; cached, downsampled avatars. |
| [`pagination_app`](pagination_app/) | **VIPER** (View / Interactor / Presenter / Entity / Router) | True server-side infinite scroll over our REST adapter, pages cached locally. |
| [`image_gallery`](image_gallery/) | **MVVM** | 100 images loaded lazily and cached (memory + disk), downsampled for battery. |

## Run

```bash
cd apps/<app>
flutter pub get
flutter run            # or: flutter run -d chrome
```

Each app uses the sibling packages via path dependencies (`../../packages/…`),
with a `dependency_overrides` pinning core to the local path (the family is
unpublished). `flutter analyze` is clean and each app ships a unit test.
