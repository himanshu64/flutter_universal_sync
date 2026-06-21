# flutter_universal_sync_hive

A [Hive](https://pub.dev/packages/hive)-backed
[`LocalDatabaseAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. Pure Dart. Hive is schemaless, so domain tables, the sync queue, and the
engine `_sync_meta` KV are stored as Hive boxes of JSON-encoded values.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_hive: ^0.1.0
  hive: ^2.2.3
```

## Use

Because Hive can't introspect "columns", register each domain table's schema so
`validateSchema` can check it.

```dart
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:path_provider/path_provider.dart';

final dir = await getApplicationDocumentsDirectory();
final local = HiveSyncAdapter(directory: dir.path);
await local.init();
local.registerTable('things', [
  'id', 'created_at', 'updated_at', 'deleted_at', 'is_synced', 'sync_status', 'name',
]);
await local.validateSchema(['things']);

final engine = SyncEngine(localDb: local, /* ... */);
```

## Notes

- **Transactions** are emulated: `transaction` snapshots the touched boxes and
  restores them if the action throws. Fine for the queue + per-row pull writes
  the engine performs; not a substitute for a real DBMS under heavy concurrency.
- **Ordering**: Hive's box iteration order is not insertion-stable, so the queue
  is ordered by an internal monotonic sequence (restart-safe).

## Conformance

Verified against core's shared `runLocalDatabaseAdapterContract` suite.

## License

MIT.
