import 'package:flutter_universal_sync_background/flutter_universal_sync_background.dart';
import 'package:test/test.dart';

void main() {
  test('BackgroundConstraints defaults: network required, no charging', () {
    const c = BackgroundConstraints();
    expect(c.requiresNetwork, isTrue);
    expect(c.requiresCharging, isFalse);
  });

  test('BackgroundConstraints can require charging', () {
    const c =
        BackgroundConstraints(requiresNetwork: false, requiresCharging: true);
    expect(c.requiresNetwork, isFalse);
    expect(c.requiresCharging, isTrue);
  });

  test('BackgroundScheduler is implementable', () async {
    final s = _FakeScheduler();
    await s.initialize();
    await s.schedulePeriodic(frequency: const Duration(minutes: 15));
    await s.cancelAll();
    expect(s.log, ['init', 'schedule:900', 'cancel']);
  });
}

class _FakeScheduler implements BackgroundScheduler {
  final log = <String>[];
  @override
  Future<void> initialize() async => log.add('init');
  @override
  Future<void> schedulePeriodic({
    required Duration frequency,
    BackgroundConstraints constraints = const BackgroundConstraints(),
  }) async =>
      log.add('schedule:${frequency.inSeconds}');
  @override
  Future<void> cancelAll() async => log.add('cancel');
}
