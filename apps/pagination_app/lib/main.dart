import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:path_provider/path_provider.dart';

import 'interactor/pagination_interactor.dart';
import 'presenter/pagination_presenter.dart';
import 'remote/paged_posts_remote.dart';
import 'router/pagination_router.dart';
import 'view/pagination_view.dart';

/// Composition root — assembles the VIPER module (View ← Presenter ←
/// Interactor → Entity/Router) over our Hive + REST adapters.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = kIsWeb
      ? 'pagination_app'
      : (await getApplicationDocumentsDirectory()).path;
  final local = HiveSyncAdapter(directory: dir);
  await local.init();

  final interactor = PaginationInteractor(
    remote: PagedPostsRemote(),
    local: local,
  );
  final presenter = PaginationPresenter(
    interactor: interactor,
    router: PaginationRouter(),
  );

  runApp(PaginationApp(presenter: presenter));
}

class PaginationApp extends StatelessWidget {
  const PaginationApp({super.key, required this.presenter});
  final PaginationPresenter presenter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pagination · VIPER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: PaginationView(presenter: presenter),
    );
  }
}
