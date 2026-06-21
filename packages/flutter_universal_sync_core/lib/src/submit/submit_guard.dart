import 'dart:async';

/// Guards against duplicate submissions — the "user triple-taps Save and three
/// identical operations get queued" problem.
///
/// Two protections, keyed by a logical action id:
/// 1. **Single-flight** — while an action for a key is in flight, further
///    `run` calls for that key do **not** start a second action; they await the
///    same result. A burst of taps collapses to one execution.
/// 2. **Cooldown** — for a short window after a *successful* run, repeat calls
///    for the key are ignored (return `null`). Failures do not cool down, so a
///    failed submit can be retried immediately.
///
/// ```dart
/// final guard = SubmitGuard();
/// onPressed: () => guard.run('save-note-$id', () => repo.save(note));
/// ```
class SubmitGuard {
  /// Creates a guard with the given post-success [cooldown]. [now] is injectable
  /// for tests.
  SubmitGuard({
    this.cooldown = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Window after a successful run during which repeat calls are ignored.
  final Duration cooldown;

  final DateTime Function() _now;
  final Map<String, Future<Object?>> _inFlight = {};
  final Map<String, DateTime> _lastSuccess = {};

  /// Whether an action for [key] is currently running.
  bool isInFlight(String key) => _inFlight.containsKey(key);

  /// Runs [action] for [key], unless it is coalesced or within the cooldown.
  ///
  /// Returns the action's result; or the in-flight result if one is already
  /// running for [key]; or `null` if the call was dropped by the cooldown.
  Future<T?> run<T>(String key, Future<T> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing.then((v) => v as T?);

    final last = _lastSuccess[key];
    if (last != null && _now().difference(last) < cooldown) {
      return Future<T?>.value();
    }

    final future = action();
    _inFlight[key] = future;
    return future.then((v) {
      _lastSuccess[key] = _now();
      return v as T?;
    }).whenComplete(() => _inFlight.remove(key));
  }
}
