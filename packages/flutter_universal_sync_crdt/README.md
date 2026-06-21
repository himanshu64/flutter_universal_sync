# flutter_universal_sync_crdt

CRDT [`ConflictResolver`](../flutter_universal_sync_core/)s for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family. Drop-in alternatives to the built-in last-write-wins / priority
resolvers, for when you want **field-level** convergence.

## `LwwMapResolver` — LWW-Element-Map

Whole-row last-write-wins loses one side entirely. An LWW-Element-Map treats each
field as its own last-write-wins register, so two devices editing **different**
fields both keep their change; a genuine same-field conflict resolves by the
larger per-field timestamp. The merge is **commutative, associative, and
idempotent** — every replica converges no matter what order changes arrive.

```dart
import 'package:flutter_universal_sync_crdt/flutter_universal_sync_crdt.dart';

const resolver = LwwMapResolver();

// On each local write, stamp the per-field clock:
final row = resolver.stamp(todo.toRow(), DateTime.now());

// Wire it into a table:
final engine = SyncEngine(
  tables: const {'todos': TableConfig(conflictResolver: LwwMapResolver())},
  /* ... */,
);
```

Per-field timestamps live in a `_lww: {field: epochMs}` sub-map on the row.
Rows without one fall back to the row's `updated_at`, degrading gracefully to
row-level LWW.

## License

MIT.
