import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Per-table configuration the sync engine uses when pulling changes.
///
/// Today this carries only [conflictResolver]. The class exists rather
/// than passing a bare [ConflictResolver] so future per-table options
/// (pull priority, soft-delete handling, batch size) can be added
/// without changing the engine's constructor signature.
class TableConfig {
  /// Creates a table config. Defaults to last-write-wins.
  const TableConfig({this.conflictResolver = const LastWriteWinsResolver()});

  /// Strategy invoked when a pulled remote row collides with a pending
  /// local edit. Inert when the table has no pending entries at pull
  /// time — the engine never invokes this for plain propagation.
  final ConflictResolver conflictResolver;
}
