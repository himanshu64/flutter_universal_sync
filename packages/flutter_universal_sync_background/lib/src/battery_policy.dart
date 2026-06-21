/// A point-in-time battery reading, supplied by your app (e.g. via
/// `battery_plus`) so this package stays plugin-free.
class BatterySnapshot {
  /// Creates a snapshot at [level] (0.0–1.0) with the given [charging] state.
  const BatterySnapshot({required this.level, required this.charging});

  /// Charge fraction, 0.0 (empty) to 1.0 (full).
  final double level;

  /// Whether the device is currently charging.
  final bool charging;
}

/// Reads the current battery state. Injected into [BackgroundSyncCoordinator].
typedef BatteryReader = Future<BatterySnapshot> Function();

/// Decides whether a background sync should run given the battery state.
///
/// The OS-level [BackgroundConstraints.requiresBatteryNotLow] already keeps the
/// scheduler from waking on low battery, but a job can still fire as the level
/// drops; this is the in-process second gate that *kills* a run early — before
/// any database or network work — to save battery.
class BatteryPolicy {
  /// Below [minLevel] charge the run is skipped, unless charging and
  /// [allowWhenCharging] is set.
  const BatteryPolicy({this.minLevel = 0.2, this.allowWhenCharging = true});

  /// Minimum charge fraction required to run on battery power.
  final double minLevel;

  /// Whether to run regardless of [minLevel] while charging.
  final bool allowWhenCharging;

  /// Whether a run is permitted for [battery].
  bool allows(BatterySnapshot battery) {
    if (battery.charging && allowWhenCharging) return true;
    return battery.level >= minLevel;
  }
}
