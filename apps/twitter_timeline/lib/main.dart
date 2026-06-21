import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:path_provider/path_provider.dart';

import 'core/connectivity_plus_monitor.dart';
import 'core/json_placeholder_remote.dart';
import 'viewmodels/timeline_viewmodel.dart';
import 'views/timeline_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = kIsWeb
      ? 'twitter_timeline'
      : (await getApplicationDocumentsDirectory()).path;
  final local = HiveSyncAdapter(directory: dir);
  await local.init();

  final engine = SyncEngine(
    localDb: local,
    remote: JsonPlaceholderRemote(),
    connectivity: ConnectivityPlusMonitor(),
    tables: const {'posts': TableConfig()},
  );
  await engine.start();

  runApp(TimelineApp(viewModel: TimelineViewModel(local: local, engine: engine)));
}

class TimelineApp extends StatelessWidget {
  const TimelineApp({super.key, required this.viewModel});
  final TimelineViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timeline · MVVM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: TimelineView(viewModel: viewModel),
    );
  }
}
