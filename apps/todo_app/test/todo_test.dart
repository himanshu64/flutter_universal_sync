import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/todo/data/todo_model.dart';
import 'package:todo_app/features/todo/domain/todo.dart';

void main() {
  test('Todo.copyWith flips completion, preserves id/title', () {
    const t = Todo(id: '1', title: 'buy milk');
    final done = t.copyWith(completed: true);
    expect(done.id, '1');
    expect(done.title, 'buy milk');
    expect(done.completed, isTrue);
  });

  test('TodoModel round-trips a row to an entity', () {
    final now = DateTime.utc(2026, 1, 1);
    final row = TodoModel.newRow('42', 'ship it', now);
    final entity = TodoModel.toEntity(row);
    expect(entity.id, '42');
    expect(entity.title, 'ship it');
    expect(entity.completed, isFalse);
  });

  test('TodoModel.toggled marks the row pending and flips completion', () {
    final now = DateTime.utc(2026, 1, 1);
    final row = TodoModel.newRow('1', 'x', now);
    final toggled = TodoModel.toggled(row, now);
    expect(TodoModel.toEntity(toggled).completed, isTrue);
    expect(toggled['sync_status'], 'pending');
    expect(toggled['is_synced'], 0);
  });
}
