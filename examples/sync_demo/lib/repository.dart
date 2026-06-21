import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import 'adapters/sqflite_adapter.dart';
import 'thing.dart';

/// Glue between the UI and the local adapter. Owns the convention that
/// every domain mutation is wrapped in `local.transaction { write + enqueue }`.
class ThingRepository {
  ThingRepository({required this.local, IdGenerator? idGen})
      : _idGen = idGen ?? UuidV4Generator();

  final SqfliteSyncAdapter local;
  final IdGenerator _idGen;
  static const String table = 'things';

  Future<List<Thing>> all() async {
    final rows = await local.getAll(table);
    return rows.map(Thing.fromMap).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<Thing> create(String name) async {
    final now = DateTime.now().toUtc();
    final thing = Thing(
      id: _idGen.nextId(),
      createdAt: now,
      updatedAt: now,
      name: name,
    );

    await local.transaction(() async {
      await local.insert(table, thing.toMap());
      await local.enqueueSync(SyncQueueEntry(
        id: _idGen.nextId(),
        table: table,
        entityId: thing.id,
        operation: SyncOperation.insert,
        payload: thing.toMap(),
        createdAt: now,
      ));
    });

    return thing;
  }

  Future<Thing> rename(Thing existing, String newName) async {
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      name: newName,
      updatedAt: now,
      isSynced: false,
      syncStatus: SyncStatus.pending,
    );

    await local.transaction(() async {
      await local.update(table, updated.id, updated.toMap());
      await local.enqueueSync(SyncQueueEntry(
        id: _idGen.nextId(),
        table: table,
        entityId: updated.id,
        operation: SyncOperation.update,
        payload: updated.toMap(),
        createdAt: now,
      ));
    });

    return updated;
  }

  Future<void> softDelete(Thing existing) async {
    final now = DateTime.now().toUtc();
    final tombstone = existing.copyWith(
      deletedAt: now,
      updatedAt: now,
      isSynced: false,
      syncStatus: SyncStatus.pending,
    );

    await local.transaction(() async {
      await local.delete(table, existing.id);
      await local.enqueueSync(SyncQueueEntry(
        id: _idGen.nextId(),
        table: table,
        entityId: existing.id,
        operation: SyncOperation.delete,
        payload: tombstone.toMap(),
        createdAt: now,
      ));
    });
  }
}
