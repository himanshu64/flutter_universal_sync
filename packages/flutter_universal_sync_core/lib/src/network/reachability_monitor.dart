import 'dart:async';

import 'network_state.dart';

/// Confirms the device can actually reach the internet, beyond the OS's
/// "interface up" flag. Return `true` if a small request to your backend (or a
/// known endpoint) succeeds. Used to catch captive portals and "connected but
/// no internet" states.
typedef ReachabilityCheck = Future<bool> Function();

/// Refines a raw OS-reported [NetworkState] stream into a *confirmed* one.
///
/// The OS reports the interface state (Wi-Fi associated, cellular up), which
/// can be wrong about real connectivity — captive portals, dead Wi-Fi, etc.
/// When a [probe] is supplied, each online transport state is verified with it;
/// if the probe fails, the state is downgraded to [NetworkState.offline].
/// Consecutive identical states are de-duplicated.
///
/// The transport stream is injected (map `connectivity_plus` results to a
/// `NetworkState`), so this is pure Dart and fully testable.
class ReachabilityMonitor {
  /// Creates a monitor over a raw [transport] state stream, optionally
  /// verifying online states with [probe].
  ReachabilityMonitor({
    required Stream<NetworkState> transport,
    ReachabilityCheck? probe,
  }) : _probe = probe {
    _sub =
        transport.listen(_onRaw, onError: (_) => _emit(NetworkState.offline));
  }

  final ReachabilityCheck? _probe;
  late final StreamSubscription<NetworkState> _sub;
  final StreamController<NetworkState> _out =
      StreamController<NetworkState>.broadcast();
  NetworkState _current = NetworkState.offline;
  NetworkState? _emitted;
  int _seq = 0;

  /// The most recent confirmed state.
  NetworkState get current => _current;

  /// Emits confirmed states (de-duplicated).
  Stream<NetworkState> get states => _out.stream;

  Future<void> _onRaw(NetworkState raw) async {
    final mine = ++_seq;
    var confirmed = raw;
    if (raw.isOnline && _probe != null) {
      final reachable = await _probe();
      if (mine != _seq) return; // a newer transport event superseded this one
      if (!reachable) confirmed = NetworkState.offline;
    }
    if (mine != _seq) return;
    _emit(confirmed);
  }

  void _emit(NetworkState state) {
    _current = state;
    if (state == _emitted) return; // de-duplicate consecutive identical states
    _emitted = state;
    if (!_out.isClosed) _out.add(state);
  }

  /// Cancels the subscription and closes the stream.
  Future<void> dispose() async {
    await _sub.cancel();
    await _out.close();
  }
}
