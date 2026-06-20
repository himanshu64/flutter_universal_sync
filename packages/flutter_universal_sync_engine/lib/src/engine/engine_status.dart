/// Coarse status of the [SyncEngine], surfaced via [SyncStateSnapshot.status].
///
/// - [idle]: not currently running a cycle. May be either "online and
///   waiting for the next trigger" or "offline".
/// - [syncing]: a drain cycle (push and optionally pull) is in flight.
/// - [error]: the most recent cycle ended with at least one push or
///   pull error. The engine is still operational and will retry on
///   the next trigger; [SyncStateSnapshot.lastError] holds the message.
enum EngineStatus {
  /// Not currently running a cycle — online and waiting, or offline.
  idle,

  /// A drain cycle (push and optionally pull) is in flight.
  syncing,

  /// The most recent cycle ended with at least one push or pull error.
  error,
}
