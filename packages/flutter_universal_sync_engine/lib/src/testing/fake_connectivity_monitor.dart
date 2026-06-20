import 'dart:async';

import '../connectivity/connectivity_monitor.dart';

/// Programmable [ConnectivityMonitor] for tests.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  /// Creates a monitor seeded to [initial] online state.
  FakeConnectivityMonitor({bool initial = true}) : _isOnline = initial;

  bool _isOnline;
  final _ctrl = StreamController<bool>.broadcast();
  final int _listenerCount = 0;

  /// How many active listeners the engine has on [onChange]. Used to
  /// assert subscription / cancellation behaviour in lifecycle tests.
  int get listenerCount => _listenerCount;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onChange => _ctrl.stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (v, sink) => sink.add(v),
        ),
      );

  /// Drives a transition. Mirrors the value to [isOnline] and emits.
  void emit(bool online) {
    _isOnline = online;
    _ctrl.add(online);
  }

  /// Closes the underlying stream controller.
  Future<void> dispose() async {
    await _ctrl.close();
  }
}
