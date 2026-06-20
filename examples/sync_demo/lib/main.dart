import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'adapters/connectivity_plus_monitor.dart';
import 'adapters/rest_adapter.dart';
import 'adapters/sqflite_adapter.dart';
import 'repository.dart';
import 'thing.dart';

/// Backend URL.
///
/// - macOS / iOS simulator / desktop: `http://localhost:<port>` works.
/// - Android emulator: replace `localhost` with `10.0.2.2`.
/// - Physical device on LAN: use the host machine's LAN IP.
///
/// The test backend defaults to port 3000, but on a machine where 3000
/// is taken use `PORT=4567 npm start` and update this URL to match.
/// You can also override at run time:
/// `flutter run --dart-define=SYNC_DEMO_BACKEND=http://192.168.1.10:4567`
const String _kBackendUrl = String.fromEnvironment(
  'SYNC_DEMO_BACKEND',
  defaultValue: 'http://localhost:4567',
);

void main() => runApp(const SyncDemoApp());

class SyncDemoApp extends StatelessWidget {
  const SyncDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sync Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<AppState> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _bootstrapApp();
  }

  Future<AppState> _bootstrapApp() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sync_demo.db');
    final local = SqfliteSyncAdapter(dbPath: dbPath);
    await local.init();
    await local.validateSchema(['things']);
    final remote = RestSyncAdapter(baseUrl: Uri.parse(_kBackendUrl));
    final repository = ThingRepository(local: local);
    final connectivity = ConnectivityPlusMonitor();
    final engine = SyncEngine(
      localDb: local,
      remote: remote,
      connectivity: connectivity,
      tables: const {
        'things': TableConfig(conflictResolver: LastWriteWinsResolver()),
      },
    );
    await engine.start();
    return AppState(
      repository: repository,
      engine: engine,
      connectivity: connectivity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _bootstrap,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Sync Demo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to start: ${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ThingsPage(state: snap.data!);
      },
    );
  }
}

class AppState {
  AppState({
    required this.repository,
    required this.engine,
    required this.connectivity,
  });
  final ThingRepository repository;
  final SyncEngine engine;
  final ConnectivityPlusMonitor connectivity;
}

class ThingsPage extends StatefulWidget {
  const ThingsPage({super.key, required this.state});
  final AppState state;

  @override
  State<ThingsPage> createState() => _ThingsPageState();
}

class _ThingsPageState extends State<ThingsPage> {
  List<Thing> _items = [];
  bool _loading = true;
  EngineStatus _status = EngineStatus.idle;
  int _pendingCount = 0;
  String? _lastError;
  StreamSubscription<SyncStateSnapshot>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.state.engine.state.listen((snap) {
      if (!mounted) return;
      setState(() {
        _status = snap.status;
        _pendingCount = snap.pendingCount;
        _lastError = snap.lastError;
      });
      // A finished cycle may have flipped local rows to synced; refresh
      // so their cloud_done icons update.
      if (snap.status == EngineStatus.idle) {
        _refresh();
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await widget.state.repository.all();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _lastError = '$e';
      });
    }
  }

  Future<void> _sync() async {
    try {
      await widget.state.engine.syncNow(pull: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
    await _refresh();
  }

  Future<void> _addItem() async {
    final name = await _promptName(context, title: 'New thing');
    if (name == null || name.trim().isEmpty) return;
    await widget.state.repository.create(name.trim());
    await _refresh();
    await _sync();
  }

  Future<void> _editItem(Thing t) async {
    final name = await _promptName(context, title: 'Rename', initial: t.name);
    if (name == null || name.trim().isEmpty || name == t.name) return;
    await widget.state.repository.rename(t, name.trim());
    await _refresh();
    await _sync();
  }

  Future<void> _deleteItem(Thing t) async {
    await widget.state.repository.softDelete(t);
    await _refresh();
    await _sync();
  }

  Widget _statusIcon() {
    if (_status == EngineStatus.syncing) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      onPressed: _sync,
      icon: Icon(
        _status == EngineStatus.error ? Icons.sync_problem : Icons.sync,
      ),
      tooltip: _pendingCount > 0 ? 'Sync now ($_pendingCount pending)' : 'Sync now',
    );
  }

  Widget _itemTile(Thing t) {
    final IconData icon;
    final Color color;
    switch (t.syncStatus) {
      case SyncStatus.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        break;
      case SyncStatus.pending:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        break;
      case SyncStatus.syncing:
        icon = Icons.cloud_sync;
        color = Colors.blue;
        break;
      case SyncStatus.failed:
        icon = Icons.cloud_off;
        color = Colors.red;
        break;
    }
    return Dismissible(
      key: ValueKey(t.id),
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(t),
      child: ListTile(
        title: Text(t.name),
        subtitle: Text('id: ${t.id.substring(0, 8)}…'),
        leading: Icon(icon, color: color),
        onTap: () => _editItem(t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Demo'),
        actions: [_statusIcon()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _sync,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 200),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nothing here yet.\nTap + to add — it will sync to $_kBackendUrl.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _itemTile(_items[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _lastError == null
          ? null
          : Container(
              color: Colors.redAccent.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(8),
              child: Text(
                _lastError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
