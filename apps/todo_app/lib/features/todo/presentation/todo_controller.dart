import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import '../domain/todo.dart';
import '../domain/todo_usecases.dart';

/// Presentation state. Talks only to use cases (never the repository or
/// engine directly) and exposes a plain listenable for the View.
class TodoController extends ChangeNotifier {
  TodoController({
    required GetTodos getTodos,
    required AddTodo addTodo,
    required ToggleTodo toggleTodo,
    required DeleteTodo deleteTodo,
    required SyncTodos syncTodos,
    required Stream<SyncStateSnapshot> syncState,
  })  : _getTodos = getTodos,
        _addTodo = addTodo,
        _toggleTodo = toggleTodo,
        _deleteTodo = deleteTodo,
        _syncTodos = syncTodos {
    _sub = syncState.listen(_onSyncState);
    _load();
  }

  final GetTodos _getTodos;
  final AddTodo _addTodo;
  final ToggleTodo _toggleTodo;
  final DeleteTodo _deleteTodo;
  final SyncTodos _syncTodos;
  late final StreamSubscription<SyncStateSnapshot> _sub;

  List<Todo> todos = const [];
  SyncStateSnapshot? sync;
  bool loading = true;

  Future<void> _load() async {
    todos = await _getTodos();
    loading = false;
    notifyListeners();
  }

  void _onSyncState(SyncStateSnapshot s) {
    sync = s;
    notifyListeners();
    // A finished cycle may have flipped rows to synced — refresh the view.
    if (s.status == EngineStatus.idle) _load();
  }

  Future<void> add(String title) async {
    await _addTodo(title);
    await _load();
    await _syncTodos();
  }

  Future<void> toggle(Todo todo) async {
    await _toggleTodo(todo);
    await _load();
    await _syncTodos();
  }

  Future<void> remove(Todo todo) async {
    await _deleteTodo(todo);
    await _load();
    await _syncTodos();
  }

  Future<void> syncNow() => _syncTodos();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
