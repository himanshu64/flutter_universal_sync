import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test('runs pending migrations in order and records the version', () async {
    final adapter = InMemoryAdapter();
    final migrator = SchemaMigrator(adapter);
    final applied = <int>[];

    final result = await migrator.migrate([
      SchemaMigration(version: 2, migrate: () async => applied.add(2)),
      SchemaMigration(version: 1, migrate: () async => applied.add(1)),
      SchemaMigration(version: 3, migrate: () async => applied.add(3)),
    ]);

    expect(applied, [1, 2, 3]); // ascending regardless of input order
    expect(result, 3);
    expect(await migrator.currentVersion(), 3);
  });

  test('skips migrations at or below the stored version', () async {
    final adapter = InMemoryAdapter();
    final migrator = SchemaMigrator(adapter);
    await migrator.migrate([
      SchemaMigration(version: 1, migrate: () async {}),
    ]);

    final ran = <int>[];
    final result = await migrator.migrate([
      SchemaMigration(version: 1, migrate: () async => ran.add(1)),
      SchemaMigration(version: 2, migrate: () async => ran.add(2)),
    ]);

    expect(ran, [2]); // v1 already applied
    expect(result, 2);
  });

  test('a failing migration rolls back and leaves the version unchanged',
      () async {
    final adapter = InMemoryAdapter();
    final migrator = SchemaMigrator(adapter);

    await expectLater(
      migrator.migrate([
        SchemaMigration(version: 1, migrate: () async {}),
        SchemaMigration(
          version: 2,
          migrate: () async => throw StateError('bad DDL'),
        ),
      ]),
      throwsStateError,
    );

    // v1 committed, v2 rolled back.
    expect(await migrator.currentVersion(), 1);
  });

  test('rejects duplicate or non-positive versions', () async {
    final migrator = SchemaMigrator(InMemoryAdapter());

    await expectLater(
      migrator.migrate([
        SchemaMigration(version: 1, migrate: () async {}),
        SchemaMigration(version: 1, migrate: () async {}),
      ]),
      throwsArgumentError,
    );
    await expectLater(
      migrator.migrate([
        SchemaMigration(version: 0, migrate: () async {}),
      ]),
      throwsArgumentError,
    );
  });

  test('no migrations is a no-op at version 0', () async {
    final migrator = SchemaMigrator(InMemoryAdapter());
    expect(await migrator.migrate([]), 0);
  });

  test('honours a custom meta key', () async {
    final adapter = InMemoryAdapter();
    final migrator = SchemaMigrator(adapter, metaKey: 'app_db_version');
    await migrator.migrate([SchemaMigration(version: 5, migrate: () async {})]);
    expect(await adapter.getMeta('app_db_version'), '5');
  });
}
