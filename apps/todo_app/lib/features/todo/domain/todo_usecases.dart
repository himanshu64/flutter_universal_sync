import 'todo.dart';
import 'todo_repository.dart';

/// One thin use case per intent — the presentation layer talks only to these,
/// keeping it ignorant of the repository's shape.
class GetTodos {
  const GetTodos(this._repo);
  final TodoRepository _repo;
  Future<List<Todo>> call() => _repo.getTodos();
}

class AddTodo {
  const AddTodo(this._repo);
  final TodoRepository _repo;
  Future<void> call(String title) => _repo.add(title);
}

class ToggleTodo {
  const ToggleTodo(this._repo);
  final TodoRepository _repo;
  Future<void> call(Todo todo) => _repo.toggle(todo);
}

class DeleteTodo {
  const DeleteTodo(this._repo);
  final TodoRepository _repo;
  Future<void> call(Todo todo) => _repo.delete(todo);
}

class SyncTodos {
  const SyncTodos(this._repo);
  final TodoRepository _repo;
  Future<void> call() => _repo.sync();
}
