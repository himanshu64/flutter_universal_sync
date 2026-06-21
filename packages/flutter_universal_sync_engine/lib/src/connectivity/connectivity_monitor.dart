/// Reports network availability to the sync engine.
///
/// The engine treats `isOnline == true` as permission to push and pull;
/// it never inspects what kind of network is up. Implementations that
/// care about metered vs. unmetered, or about a heartbeat against a
/// custom endpoint, supply their own logic and surface the result here.
///
/// `onChange` MUST be a broadcast stream — the engine subscribes once
/// per `start()` call. The stream MUST emit only on transitions
/// (false→true and true→false); duplicate consecutive values are
/// permitted but waste cycles.
///
/// `isOnline` MUST reflect the most recent emitted value (or the seed
/// state if nothing has been emitted yet). Concretely: a subscriber
/// that starts listening after `onChange` has emitted `true` will see
/// `isOnline == true` even though it missed the event itself.
abstract class ConnectivityMonitor {
  /// Whether the engine currently has permission to make network calls.
  bool get isOnline;

  /// Broadcast stream of online-state transitions.
  Stream<bool> get onChange;
}
