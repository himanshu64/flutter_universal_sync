import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import 'todo.dart';

/// Domain boundary — the presentation/use-case layers depend on this
/// abstraction, never on the sync engine or Hive directly. The data layer
/// provides the implementation.
abstract class TodoRepository {
  /// All non-deleted todos, newest first, read from the local store.
  Future<List<Todo>> getTodos();

  /// Adds a todo locally (optimistic) and queues it for push.
  Future<void> add(String title);

  /// Flips completion locally and queues the update.
  Future<void> toggle(Todo todo);

  /// Soft-deletes locally and queues the delete.
  Future<void> delete(Todo todo);

  /// Runs one sync cycle (push the queue, then pull remote changes).
  Future<void> sync();

  /// Live engine state (idle / syncing / error + pending count).
  Stream<SyncStateSnapshot> get syncState;
}
