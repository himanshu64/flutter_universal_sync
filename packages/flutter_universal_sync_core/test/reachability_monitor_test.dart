import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:test/test.dart';

void main() {
  test('NetworkState exposes online/metered helpers', () {
    expect(NetworkState.offline.isOnline, isFalse);
    expect(NetworkState.metered.isOnline, isTrue);
    expect(NetworkState.metered.isMetered, isTrue);
    expect(NetworkState.unmetered.isMetered, isFalse);
  });

  test('passes through transport states when no probe is given', () async {
    final raw = StreamController<NetworkState>();
    final monitor = ReachabilityMonitor(transport: raw.stream);
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw
      ..add(NetworkState.unmetered)
      ..add(NetworkState.metered)
      ..add(NetworkState.offline);
    await pump();

    expect(seen, [
      NetworkState.unmetered,
      NetworkState.metered,
      NetworkState.offline,
    ]);
    expect(monitor.current, NetworkState.offline);
    await monitor.dispose();
  });

  test('downgrades to offline when the probe fails (captive portal)', () async {
    final raw = StreamController<NetworkState>();
    final monitor = ReachabilityMonitor(
      transport: raw.stream,
      probe: () async => false, // interface up but no real internet
    );
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw.add(NetworkState.unmetered);
    await pump();

    expect(seen, [NetworkState.offline]);
    await monitor.dispose();
  });

  test('keeps the state when the probe confirms reachability', () async {
    final raw = StreamController<NetworkState>();
    final monitor = ReachabilityMonitor(
      transport: raw.stream,
      probe: () async => true,
    );
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw.add(NetworkState.metered);
    await pump();

    expect(seen, [NetworkState.metered]);
    await monitor.dispose();
  });

  test('de-duplicates consecutive identical states', () async {
    final raw = StreamController<NetworkState>();
    final monitor = ReachabilityMonitor(transport: raw.stream);
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw
      ..add(NetworkState.unmetered)
      ..add(NetworkState.unmetered)
      ..add(NetworkState.unmetered);
    await pump();

    expect(seen, [NetworkState.unmetered]);
    await monitor.dispose();
  });

  test('a newer transport event supersedes a slow in-flight probe', () async {
    final raw = StreamController<NetworkState>();
    final gate = Completer<bool>();
    var calls = 0;
    final monitor = ReachabilityMonitor(
      transport: raw.stream,
      probe: () async {
        calls++;
        // First probe blocks; later events should win.
        return calls == 1 ? gate.future : true;
      },
    );
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw.add(NetworkState.unmetered); // starts the slow probe
    await pump();
    raw.add(NetworkState.offline); // supersedes before the probe resolves
    await pump();
    gate.complete(true); // late result for the superseded event
    await pump();

    expect(seen, [NetworkState.offline]);
    expect(monitor.current, NetworkState.offline);
    await monitor.dispose();
  });

  test('a transport error is treated as offline', () async {
    final raw = StreamController<NetworkState>();
    final monitor = ReachabilityMonitor(transport: raw.stream);
    final seen = <NetworkState>[];
    monitor.states.listen(seen.add);

    raw.addError(StateError('transport blew up'));
    await pump();

    expect(seen, [NetworkState.offline]);
    await monitor.dispose();
  });
}

Future<void> pump([int turns = 3]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
