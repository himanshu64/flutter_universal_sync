import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import '../domain/todo.dart';

/// Translates between the [Todo] entity and the row map the sync family
/// stores (domain fields + the required [SyncColumns]).
class TodoModel {
  TodoModel._();

  static const table = 'todos';

  static bool _isCompleted(Object? v) => v == 1 || v == true;

  /// A fresh, locally-created row: pending and unsynced.
  static Map<String, dynamic> newRow(String id, String title, DateTime now) {
    final ms = now.toUtc().millisecondsSinceEpoch;
    return {
      SyncColumns.id: id,
      'title': title,
      'completed': 0,
      SyncColumns.createdAt: ms,
      SyncColumns.updatedAt: ms,
      SyncColumns.deletedAt: null,
      SyncColumns.isSynced: 0,
      SyncColumns.syncStatus: 'pending',
    };
  }

  /// Returns [row] with completion flipped and marked pending for re-push.
  static Map<String, dynamic> toggled(Map<String, dynamic> row, DateTime now) =>
      {
        ...row,
        'completed': _isCompleted(row['completed']) ? 0 : 1,
        SyncColumns.updatedAt: now.toUtc().millisecondsSinceEpoch,
        SyncColumns.isSynced: 0,
        SyncColumns.syncStatus: 'pending',
      };

  static Todo toEntity(Map<String, dynamic> row) => Todo(
        id: row[SyncColumns.id] as String,
        title: (row['title'] ?? '') as String,
        completed: _isCompleted(row['completed']),
      );
}
