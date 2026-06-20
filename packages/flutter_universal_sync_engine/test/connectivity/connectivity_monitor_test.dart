import 'dart:async';

import 'package:flutter_universal_sync_engine/src/connectivity/connectivity_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('ConnectivityMonitor is abstract', () {
    expect(
      () => (ConnectivityMonitor as dynamic)(),
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('a concrete implementation satisfies the contract', () async {
    final monitor = _ConcreteMonitor(initial: false);
    expect(monitor.isOnline, isFalse);
    final events = <bool>[];
    final sub = monitor.onChange.listen(events.add);
    monitor.set(true);
    monitor.set(false);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, [true, false]);
    expect(monitor.isOnline, isFalse);
  });
}

class _ConcreteMonitor implements ConnectivityMonitor {
  _ConcreteMonitor({required bool initial}) : _isOnline = initial;
  bool _isOnline;
  final _ctrl = StreamController<bool>.broadcast();
  void set(bool v) {
    _isOnline = v;
    _ctrl.add(v);
  }

  @override
  bool get isOnline => _isOnline;
  @override
  Stream<bool> get onChange => _ctrl.stream;
}
