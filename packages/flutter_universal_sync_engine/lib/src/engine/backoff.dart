import 'dart:math' as math;

/// Default backoff schedule used by the engine when a push fails.
///
/// `min(2^retryCount * 1s, 5min)`. `retryCount == 0` returns `1s`.
/// Negative input is treated as 0. Pure function — safe to call from
/// any isolate.
///
/// Override by passing a different `Duration Function(int)` to the
/// `SyncEngine` constructor's `backoff` parameter.
Duration defaultBackoff(int retryCount) {
  if (retryCount <= 0) return const Duration(seconds: 1);
  // Cap exponent before pow to avoid overflow on huge retry counts.
  final exp = math.min(retryCount, 30);
  final ms = math.pow(2, exp).toInt() * 1000;
  const capMs = 5 * 60 * 1000;
  return Duration(milliseconds: math.min(ms, capMs));
}
