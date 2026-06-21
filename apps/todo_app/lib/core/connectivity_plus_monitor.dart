import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_universal_sync_engine/flutter_universal_sync_engine.dart';

/// `connectivity_plus`-backed [ConnectivityMonitor]. Online whenever any
/// interface is connected; the engine treats that as permission to sync.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
      }
    });
    unawaited(_seed());
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true; // optimistic until the seed completes

  Future<void> _seed() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
  }

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onChange => _controller.stream;

  Future<void> dispose() async {
    await _sub.cancel();
    await _controller.close();
  }
}
