import 'dart:async';

import 'package:flutter_universal_sync_engine/src/engine/_clock.dart';

/// Manually advanceable clock for engine tests. Calls to [delay] return
/// futures that complete only when [advance] (or [advanceTo]) moves the
/// virtual clock past the future's deadline.
class FakeClock implements Clock {
  FakeClock({DateTime? start}) : _now = start ?? DateTime.utc(2026, 1, 1, 12);

  DateTime _now;
  final List<_Pending> _pending = [];

  @override
  DateTime now() => _now;

  @override
  Future<void> delay(Duration d) {
    final completer = Completer<void>();
    _pending.add(_Pending(_now.add(d), completer));
    return completer.future;
  }

  /// Advances the clock by [d], completing every pending [delay] whose
  /// deadline has elapsed.
  void advance(Duration d) {
    _now = _now.add(d);
    _flush();
  }

  /// Advances the clock to a specific moment.
  void advanceTo(DateTime target) {
    if (target.isBefore(_now)) {
      throw ArgumentError.value(
        target,
        'target',
        'cannot move clock backwards',
      );
    }
    _now = target;
    _flush();
  }

  void _flush() {
    final ready = _pending.where((p) => !p.deadline.isAfter(_now)).toList();
    _pending.removeWhere(ready.contains);
    for (final p in ready) {
      p.completer.complete();
    }
  }
}

class _Pending {
  _Pending(this.deadline, this.completer);
  final DateTime deadline;
  final Completer<void> completer;
}
