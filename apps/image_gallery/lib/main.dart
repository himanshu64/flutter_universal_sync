import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_universal_sync_hive/flutter_universal_sync_hive.dart';
import 'package:path_provider/path_provider.dart';

import 'remote/images_remote.dart';
import 'viewmodels/gallery_viewmodel.dart';
import 'views/gallery_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = kIsWeb
      ? 'image_gallery'
      : (await getApplicationDocumentsDirectory()).path;
  final local = HiveSyncAdapter(directory: dir);
  await local.init();

  final viewModel = GalleryViewModel(local: local, remote: ImagesRemote());
  runApp(GalleryApp(viewModel: viewModel));
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, required this.viewModel});
  final GalleryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery · MVVM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: GalleryView(viewModel: viewModel),
    );
  }
}
