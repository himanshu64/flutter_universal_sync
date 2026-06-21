import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

import '../models/tweet.dart';

/// The ViewModel — owns presentation state and the commands the View binds
/// to. It reads the local cache first (instant, offline) then triggers a
/// pull; the View never touches the engine or Hive.
class TimelineViewModel extends ChangeNotifier {
  TimelineViewModel({required this.local, required this.engine}) {
    _sub = engine.state.listen(_onState);
    refresh();
  }

  final LocalDatabaseAdapter local;
  final SyncEngine engine;
  static const table = 'posts';

  List<Tweet> tweets = const [];
  bool loading = true;
  bool syncing = false;
  String? error;

  late final StreamSubscription<SyncStateSnapshot> _sub;

  Future<void> _loadLocal() async {
    final rows = await local.getAll(table)
      ..sort((a, b) => (b[SyncColumns.createdAt] as int? ?? 0)
          .compareTo(a[SyncColumns.createdAt] as int? ?? 0));
    tweets = rows.map(Tweet.fromRow).toList();
    loading = false;
    notifyListeners();
  }

  void _onState(SyncStateSnapshot s) {
    syncing = s.status == EngineStatus.syncing;
    error = s.lastError;
    notifyListeners();
    if (s.status == EngineStatus.idle) _loadLocal();
  }

  /// Command: show cached tweets immediately, then pull fresh ones.
  Future<void> refresh() async {
    await _loadLocal();
    await engine.syncNow(pull: true);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
