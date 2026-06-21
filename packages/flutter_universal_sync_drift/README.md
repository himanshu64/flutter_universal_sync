# flutter_universal_sync_drift

A [drift](https://pub.dev/packages/drift)-backed
[`LocalDatabaseAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. No code-gen: it drives a private drift database entirely through raw SQL,
so it slots into any drift setup. Pure Dart — the `QueryExecutor` is injected.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_drift: ^0.1.0
  drift: ^2.0.0
```

## Use

The adapter owns two internal tables (`sync_queue`, `_sync_meta`), created on
`init()`. You own your domain tables — create them via `database` and call
`validateSchema`.

```dart
import 'package:drift/native.dart';
import 'package:flutter_universal_sync_drift/flutter_universal_sync_drift.dart';

final local = DriftSyncAdapter(
  executor: NativeDatabase(File('app.db')),   // or LazyDatabase, etc.
);
await local.init();

await local.database.customStatement('''
  CREATE TABLE things (
    id TEXT PRIMARY KEY NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    is_synced INTEGER NOT NULL DEFAULT 0,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    name TEXT
  )
''');
await local.validateSchema(['things']);

final engine = SyncEngine(localDb: local, /* ... */);
```

### Testing (headless)

```dart
import 'package:drift/native.dart';
final local = DriftSyncAdapter(executor: NativeDatabase.memory());
```

## Conformance

Verified against core's shared `runLocalDatabaseAdapterContract` suite.

## License

MIT.
