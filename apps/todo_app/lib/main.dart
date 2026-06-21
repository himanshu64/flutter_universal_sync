import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:path_provider/path_provider.dart';

import 'core/connectivity_plus_monitor.dart';
import 'core/json_placeholder_remote.dart';
import 'features/todo/data/todo_repository_impl.dart';
import 'features/todo/domain/todo_usecases.dart';
import 'features/todo/presentation/todo_controller.dart';
import 'features/todo/presentation/todo_page.dart';

/// Composition root — the one place that knows the concrete types and wires
/// the dependency graph (outer layers → inner). Everything below depends only
/// on abstractions.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir =
      kIsWeb ? 'todo_app' : (await getApplicationDocumentsDirectory()).path;
  final local = HiveSyncAdapter(directory: dir);
  await local.init();

  final engine = SyncEngine(
    localDb: local,
    remote: JsonPlaceholderRemote(),
    connectivity: ConnectivityPlusMonitor(),
    tables: const {'todos': TableConfig()},
  );
  await engine.start();

  final repo = TodoRepositoryImpl(
    local: local,
    engine: engine,
    idGen: UuidV4Generator(),
  );
  final controller = TodoController(
    getTodos: GetTodos(repo),
    addTodo: AddTodo(repo),
    toggleTodo: ToggleTodo(repo),
    deleteTodo: DeleteTodo(repo),
    syncTodos: SyncTodos(repo),
    syncState: repo.syncState,
  );

  runApp(TodoApp(controller: controller));
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.controller});
  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo · Clean Architecture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: TodoPage(controller: controller),
    );
  }
}
