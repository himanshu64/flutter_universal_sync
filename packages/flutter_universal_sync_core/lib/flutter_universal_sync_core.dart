/// Core contracts for the flutter_universal_sync offline-first package family.
///
/// See `README.md` for architectural context and the public API.
library;

export 'src/adapters/local_database_adapter.dart';
export 'src/adapters/remote_sync_adapter.dart';
export 'src/cache/cache_evictor.dart';
export 'src/cache/purgeable_adapter.dart';
export 'src/conflict/client_priority_resolver.dart';
export 'src/conflict/conflict_resolver.dart';
export 'src/conflict/last_write_wins_resolver.dart';
export 'src/conflict/server_priority_resolver.dart';
export 'src/entities/sync_entity.dart';
export 'src/entities/sync_operation.dart';
export 'src/entities/sync_queue_entry.dart';
export 'src/entities/sync_status.dart';
export 'src/errors/sync_errors.dart';
export 'src/id/id_generator.dart';
export 'src/migration/schema_migrator.dart';
export 'src/network/network_state.dart';
export 'src/network/reachability_monitor.dart';
export 'src/pagination/keyset.dart';
export 'src/pagination/page.dart';
export 'src/pagination/paginated_adapter.dart';
export 'src/schema/sync_columns.dart';
export 'src/submit/submit_guard.dart';
