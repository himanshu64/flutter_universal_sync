import 'package:flutter/foundation.dart';
import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import '../models/photo.dart';
import '../remote/images_remote.dart';

/// ViewModel — caches 100 photo records locally (offline) and exposes them.
/// The image *binaries* are cached by `cached_network_image` in the View; this
/// caches the *metadata* in the local store via our adapter.
class GalleryViewModel extends ChangeNotifier {
  GalleryViewModel({required this.local, required this.remote}) {
    _init();
  }

  final LocalDatabaseAdapter local;
  final ImagesRemote remote;
  static const table = 'photos';

  List<Photo> photos = const [];
  bool loading = true;
  bool syncing = false;
  String? error;

  Future<void> _loadLocal() async {
    final rows = await local.getAll(table)
      ..sort((a, b) => _id(a).compareTo(_id(b)));
    photos = rows.map(Photo.fromRow).toList();
    loading = false;
    notifyListeners();
  }

  Future<void> _init() async {
    await _loadLocal(); // instant from cache, even offline
    await refresh();
  }

  Future<void> refresh() async {
    syncing = true;
    notifyListeners();
    try {
      final rows = await remote.fetchPhotos();
      await local.transaction(() async {
        for (final r in rows) {
          await local.upsert(table, r);
        }
      });
      error = null;
    } catch (e) {
      error = '$e';
    }
    syncing = false;
    await _loadLocal();
  }

  int _id(Map<String, dynamic> r) =>
      int.tryParse('${r[SyncColumns.id] ?? r['id']}') ?? 0;
}
