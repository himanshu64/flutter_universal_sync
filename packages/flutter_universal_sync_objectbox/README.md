# flutter_universal_sync_objectbox

An [ObjectBox](https://pub.dev/packages/objectbox)-backed
[`LocalDatabaseAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family.

> **Status: reference implementation / skeleton.** Unlike the sqflite, drift,
> and hive adapters in this repo, this package was **not** executed against the
> shared contract suite in the authoring environment, because ObjectBox needs
> two things that environment could not provide:
> 1. **Generated bindings** (`objectbox.g.dart`) via `build_runner` — blocked
>    there by an `analyzer` / `source_gen` version skew on Dart 3.11.
> 2. The **ObjectBox native library** (`libobjectbox`) — its installer is a
>    remote shell script that the sandbox blocked.
>
> The adapter is written to mirror the verified in-memory / Hive adapters; run
> the steps below in a normal environment to generate bindings and validate it.

## Design

ObjectBox is strongly typed, so every stored fact — domain rows, queue entries,
meta KV pairs — lives in one generic `SyncRecord` entity discriminated by
`kind` (`row` / `queue` / `meta`). The adapter satisfies the interface by
querying `SyncRecord`s.

## Building

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_objectbox: ^0.1.0
  objectbox: ^4.0.0
  objectbox_flutter_libs: ^4.0.0   # Flutter apps; ships the native lib
```

```bash
# 1. generate bindings:
dart run build_runner build --delete-conflicting-outputs
# 2. (pure-Dart / CI only) install the native library:
bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
# 3. run the shared contract suite:
dart test
```

## Use

```dart
final local = ObjectboxSyncAdapter(directory: 'objectbox');
await local.init();
local.registerTable('things', [
  'id', 'created_at', 'updated_at', 'deleted_at', 'is_synced', 'sync_status', 'name',
]);
await local.validateSchema(['things']);

final engine = SyncEngine(localDb: local, /* ... */);
```

## License

MIT.
