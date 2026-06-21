# flutter_universal_sync_sqflite

A SQLite-backed [`LocalDatabaseAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family, built on `sqflite_common`. Pure Dart — the `DatabaseFactory` is injected,
so it runs in a Flutter app and in headless `dart test` alike.

## Install

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_sqflite: ^0.1.0
  sqflite: ^2.4.0   # provides the Flutter databaseFactory
```

## Use

The adapter owns two internal tables (`sync_queue`, `_sync_meta`), created on
`init()`. **You own your domain tables** — create them and then call
`validateSchema`.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:flutter_universal_sync_sqflite/flutter_universal_sync_sqflite.dart';

final local = SqfliteSyncAdapter(
  databaseFactory: databaseFactory,                  // from package:sqflite
  path: '${await getDatabasesPath()}/app.db',
);
await local.init();

// Create your domain tables (must include the required SyncColumns):
await local.database.execute('''
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

// Hand it to the engine:
final engine = SyncEngine(localDb: local, /* ... */);
```

### Testing (headless)

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

sqfliteFfiInit();
final local = SqfliteSyncAdapter(
  databaseFactory: databaseFactoryFfi,
  path: inMemoryDatabasePath,
);
```

## Conformance

Verified against core's shared `runLocalDatabaseAdapterContract` suite — the same
suite every adapter in the family runs.

## License

MIT.
