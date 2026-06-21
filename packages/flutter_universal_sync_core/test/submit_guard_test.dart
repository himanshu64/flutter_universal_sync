import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:test/test.dart';

void main() {
  test('coalesces a burst of taps into a single execution', () async {
    final guard = SubmitGuard();
    var runs = 0;
    final gate = Completer<String>();
    Future<String> action() {
      runs++;
      return gate.future;
    }

    final f1 = guard.run('save', action);
    final f2 = guard.run('save', action);
    final f3 = guard.run('save', action);
    expect(runs, 1); // triple tap → one execution
    expect(guard.isInFlight('save'), isTrue);

    gate.complete('ok');
    expect(await f1, 'ok');
    expect(await f2, 'ok');
    expect(await f3, 'ok');
    expect(guard.isInFlight('save'), isFalse);
  });

  test('ignores repeat calls within the cooldown after success', () async {
    var t = DateTime.utc(2026, 1, 1);
    final guard = SubmitGuard(
      cooldown: const Duration(seconds: 1),
      now: () => t,
    );
    var runs = 0;
    Future<String> act() async => 'r${++runs}';

    expect(await guard.run('k', act), 'r1');
    expect(await guard.run('k', act), isNull); // same instant → cooled down
    expect(runs, 1);

    t = t.add(const Duration(seconds: 2)); // past the cooldown
    expect(await guard.run('k', act), 'r2');
    expect(runs, 2);
  });

  test('does not cool down after a failure (immediate retry allowed)',
      () async {
    final guard = SubmitGuard(cooldown: const Duration(seconds: 10));
    var runs = 0;
    Future<String> bad() async {
      runs++;
      throw StateError('boom');
    }

    await expectLater(guard.run('k', bad), throwsStateError);
    await expectLater(guard.run('k', bad), throwsStateError);
    expect(runs, 2);
  });

  test('keys are independent', () async {
    final guard = SubmitGuard(cooldown: const Duration(seconds: 10));
    var a = 0;
    var b = 0;
    expect(await guard.run('a', () async => ++a), 1);
    expect(await guard.run('b', () async => ++b), 1);
    expect(a, 1);
    expect(b, 1);
  });
}
