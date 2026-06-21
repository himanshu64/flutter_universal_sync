import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import '../domain/todo.dart';
import '../domain/todo_repository.dart';
import 'todo_model.dart';

/// Concrete repository: local-first writes via the [LocalDatabaseAdapter]
/// (one atomic `upsert + enqueueSync` per mutation), drained by the
/// [SyncEngine]. The domain layer never sees any of this.
class TodoRepositoryImpl implements TodoRepository {
  TodoRepositoryImpl({
    required this.local,
    required this.engine,
    required this.idGen,
  });

  final LocalDatabaseAdapter local;
  final SyncEngine engine;
  final IdGenerator idGen;

  @override
  Future<List<Todo>> getTodos() async {
    final rows = await local.getAll(TodoModel.table)
      ..sort((a, b) => (b[SyncColumns.createdAt] as int)
          .compareTo(a[SyncColumns.createdAt] as int));
    return rows.map(TodoModel.toEntity).toList();
  }

  @override
  Future<void> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().toUtc();
    final id = idGen.nextId();
    final row = TodoModel.newRow(id, trimmed, now);
    await local.transaction(() async {
      await local.upsert(TodoModel.table, row); // optimistic
      await local.enqueueSync(SyncQueueEntry(
        id: idGen.nextId(),
        table: TodoModel.table,
        entityId: id,
        operation: SyncOperation.insert,
        payload: row,
        createdAt: now,
      ));
    });
  }

  @override
  Future<void> toggle(Todo todo) async {
    final cur = await local.getById(TodoModel.table, todo.id);
    if (cur == null) return;
    final now = DateTime.now().toUtc();
    final row = TodoModel.toggled(cur, now);
    await local.transaction(() async {
      await local.upsert(TodoModel.table, row);
      await local.enqueueSync(SyncQueueEntry(
        id: idGen.nextId(),
        table: TodoModel.table,
        entityId: todo.id,
        operation: SyncOperation.update,
        payload: row,
        createdAt: now,
      ));
    });
  }

  @override
  Future<void> delete(Todo todo) async {
    final cur = await local.getById(TodoModel.table, todo.id);
    if (cur == null) return;
    final now = DateTime.now().toUtc();
    await local.transaction(() async {
      await local.delete(TodoModel.table, todo.id); // soft delete
      await local.enqueueSync(SyncQueueEntry(
        id: idGen.nextId(),
        table: TodoModel.table,
        entityId: todo.id,
        operation: SyncOperation.delete,
        payload: cur,
        createdAt: now,
      ));
    });
  }

  @override
  Future<void> sync() => engine.syncNow(); // push the queue (this app is write-first)

  @override
  Stream<SyncStateSnapshot> get syncState => engine.state;
}
