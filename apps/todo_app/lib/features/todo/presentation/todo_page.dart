import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import 'todo_controller.dart';

/// The View — dumb: it renders controller state and forwards intents.
class TodoPage extends StatelessWidget {
  const TodoPage({super.key, required this.controller});
  final TodoController controller;

  Future<void> _add(BuildContext context) async {
    final text = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New todo'),
        content: TextField(
          controller: text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What needs doing?'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, text.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await controller.add(title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final todos = controller.todos;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Todo · Clean Architecture'),
            actions: [_SyncIndicator(snapshot: controller.sync, onSync: controller.syncNow)],
          ),
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : todos.isEmpty
                  ? const Center(child: Text('No todos yet. Tap + to add one.'))
                  : ListView.builder(
                      itemCount: todos.length,
                      itemBuilder: (context, i) {
                        final t = todos[i];
                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => controller.remove(t),
                          child: CheckboxListTile(
                            value: t.completed,
                            onChanged: (_) => controller.toggle(t),
                            title: Text(
                              t.title,
                              style: t.completed
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _add(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.snapshot, required this.onSync});
  final SyncStateSnapshot? snapshot;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s?.status == EngineStatus.syncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final pending = s?.pendingCount ?? 0;
    return IconButton(
      tooltip: pending > 0 ? 'Sync now ($pending pending)' : 'Sync now',
      onPressed: onSync,
      icon: Icon(s?.status == EngineStatus.error ? Icons.sync_problem : Icons.sync),
    );
  }
}
