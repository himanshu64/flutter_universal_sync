/// Domain entity — pure, framework-free, no persistence concerns.
class Todo {
  const Todo({required this.id, required this.title, this.completed = false});

  final String id;
  final String title;
  final bool completed;

  Todo copyWith({String? title, bool? completed}) => Todo(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
      );
}
