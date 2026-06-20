import 'package:meta/meta.dart';

/// Time abstraction used by the engine internally so tests can drive
/// the clock without sleeping. Public consumers do not see this; the
/// `SyncEngine` constructor exposes a separate package-private
/// constructor variant in the same library that accepts a [Clock].
@internal
abstract class Clock {
  /// Returns the current UTC time.
  DateTime now();

  /// Returns a future that completes after [d] has elapsed on this clock.
  /// Real-time clocks delegate to `Future.delayed`; fakes can advance
  /// virtually.
  Future<void> delay(Duration d);

  /// The default real-time clock.
  static const Clock systemClock = _SystemClock();
}

class _SystemClock implements Clock {
  const _SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
  @override
  Future<void> delay(Duration d) => Future<void>.delayed(d);
}
