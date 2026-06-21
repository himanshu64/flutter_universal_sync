import '../adapters/local_database_adapter.dart';

/// One ordered, idempotent step that brings the local schema **to** [version].
class SchemaMigration {
  /// Creates a migration that, when applied, advances the stored schema version
  /// to [version]. [migrate] performs the change (DDL, backfills, …).
  const SchemaMigration({
    required this.version,
    required this.migrate,
    this.description,
  });

  /// The schema version this migration produces. Must be ≥ 1 and unique.
  final int version;

  /// The work that performs the migration. Runs inside the adapter's
  /// transaction together with the version bump.
  final Future<void> Function() migrate;

  /// Optional human-readable note (logged by callers if desired).
  final String? description;
}

/// Runs ordered [SchemaMigration]s against a [LocalDatabaseAdapter], tracking
/// the applied version in the adapter's meta KV.
///
/// Each pending migration runs inside [LocalDatabaseAdapter.transaction] with
/// the version bump, so a failure rolls back the step and leaves the stored
/// version unchanged — the migration re-runs next launch. Migrations must
/// therefore be written to be safe to retry.
class SchemaMigrator {
  /// Creates a migrator for [adapter], storing the version under [metaKey].
  SchemaMigrator(this.adapter, {this.metaKey = '_schema_version'});

  /// The store whose schema is migrated (and whose meta KV holds the version).
  final LocalDatabaseAdapter adapter;

  /// Meta key the current schema version is persisted under.
  final String metaKey;

  /// The currently-applied schema version (`0` if never migrated).
  Future<int> currentVersion() async =>
      int.tryParse(await adapter.getMeta(metaKey) ?? '') ?? 0;

  /// Applies every migration whose [SchemaMigration.version] exceeds the stored
  /// version, in ascending order, and returns the resulting version.
  ///
  /// Throws [ArgumentError] if versions are not unique and ≥ 1.
  Future<int> migrate(List<SchemaMigration> migrations) async {
    final sorted = [...migrations]
      ..sort((a, b) => a.version.compareTo(b.version));
    final seen = <int>{};
    for (final m in sorted) {
      if (m.version < 1) {
        throw ArgumentError.value(m.version, 'version', 'must be >= 1');
      }
      if (!seen.add(m.version)) {
        throw ArgumentError.value(m.version, 'version', 'duplicate migration');
      }
    }

    var version = await currentVersion();
    for (final m in sorted) {
      if (m.version <= version) continue;
      await adapter.transaction(() async {
        await m.migrate();
        await adapter.setMeta(metaKey, '${m.version}');
      });
      version = m.version;
    }
    return version;
  }
}
