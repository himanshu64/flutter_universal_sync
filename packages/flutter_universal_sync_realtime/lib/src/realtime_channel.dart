import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

import 'realtime_event.dart';

/// Connection state of a [RealtimeChannel].
enum RealtimeStatus {
  /// Not connected and not trying.
  disconnected,

  /// Opening (or re-opening) the transport.
  connecting,

  /// Connected and receiving events.
  connected,
}

/// Opens a fresh event stream. Called once per (re)connect, so each call should
/// establish a new transport (e.g. a new WebSocket subscription).
typedef RealtimeSource = Stream<RealtimeEvent> Function();

/// Exponential reconnect backoff: 200ms, 400ms, 800ms … capped at 30s.
Duration defaultRealtimeBackoff(int attempt) {
  final shift = attempt < 1 ? 0 : attempt - 1;
  final ms = shift >= 8 ? 30000 : 200 * (1 << shift);
  return Duration(milliseconds: ms > 30000 ? 30000 : ms);
}

/// Keeps a realtime subscription alive and applies incoming row events to a
/// local store, reconnecting (with backoff) when the transport drops.
///
/// The transport is injected as a [RealtimeSource] — a thunk returning a
/// `Stream<RealtimeEvent>` — so this package stays backend-agnostic and is
/// fully testable with plain `StreamController`s (no real socket).
///
/// For each event, in order:
/// 1. if [onEvent] is set, it is called (full control — e.g. trigger a pull);
/// 2. else if a [localDb] is set and the event carries a `row`, the row is
///    `upsert`ed (a `delete` event should carry a tombstone row with
///    `deleted_at` set, so it applies the same way);
/// 3. else the event is ignored.
class RealtimeChannel {
  /// Creates a channel over [connect].
  ///
  /// Provide [localDb] to auto-apply row events, and/or [onEvent] for custom
  /// handling. [onError] observes transport/handler errors. [reconnectBackoff]
  /// maps a 1-based attempt to a delay (defaults to [defaultRealtimeBackoff]);
  /// [maxReconnectAttempts] caps retries (`null` = forever). [sleep] is
  /// injectable so tests run without real delays.
  RealtimeChannel({
    required this.connect,
    this.localDb,
    this.onEvent,
    this.onError,
    Duration Function(int attempt)? reconnectBackoff,
    this.maxReconnectAttempts,
    Future<void> Function(Duration delay)? sleep,
  })  : reconnectBackoff = reconnectBackoff ?? defaultRealtimeBackoff,
        _sleep = sleep ?? Future<void>.delayed;

  /// Opens a new event stream per (re)connect.
  final RealtimeSource connect;

  /// Optional local store row events are applied to.
  final LocalDatabaseAdapter? localDb;

  /// Optional custom handler invoked for every event (overrides auto-apply).
  final Future<void> Function(RealtimeEvent event)? onEvent;

  /// Optional observer for transport and handler errors.
  final void Function(Object error)? onError;

  /// Maps a 1-based reconnect attempt to a delay.
  final Duration Function(int attempt) reconnectBackoff;

  /// Maximum reconnect attempts before giving up, or `null` for unlimited.
  final int? maxReconnectAttempts;

  final Future<void> Function(Duration delay) _sleep;

  final StreamController<RealtimeStatus> _status =
      StreamController<RealtimeStatus>.broadcast();
  RealtimeStatus _current = RealtimeStatus.disconnected;
  bool _stopped = false;
  StreamSubscription<RealtimeEvent>? _sub;
  Completer<void>? _ended;
  Future<void>? _loop;

  /// The current connection status.
  RealtimeStatus get status => _current;

  /// Emits on every status transition.
  Stream<RealtimeStatus> get statusStream => _status.stream;

  /// Starts connecting. The returned future completes when the channel stops
  /// (via [stop]) or exhausts [maxReconnectAttempts).
  Future<void> start() {
    _stopped = false;
    return _loop ??= _connectLoop();
  }

  /// Stops the channel and cancels the active subscription. No further
  /// reconnects occur.
  Future<void> stop() async {
    _stopped = true;
    // Unblock the loop if it is waiting on the current connection.
    if (_ended != null && !_ended!.isCompleted) _ended!.complete();
    await _sub?.cancel();
    _sub = null;
    final loop = _loop;
    _loop = null;
    await loop;
    _setStatus(RealtimeStatus.disconnected);
  }

  /// Stops the channel and closes the status stream. Use when discarding it.
  Future<void> dispose() async {
    await stop();
    await _status.close();
  }

  Future<void> _connectLoop() async {
    var attempt = 0;
    while (!_stopped) {
      _setStatus(RealtimeStatus.connecting);
      final ended = _ended = Completer<void>();
      try {
        final sub = connect().listen(
          null,
          onError: (Object e) {
            onError?.call(e);
            if (!ended.isCompleted) ended.complete();
          },
          onDone: () {
            if (!ended.isCompleted) ended.complete();
          },
          cancelOnError: true,
        );
        // Serialize async handling and apply backpressure: pause the
        // subscription until each event has been applied.
        sub.onData((event) {
          sub.pause(
            _handle(event).catchError((Object e) => onError?.call(e)),
          );
        });
        _sub = sub;
      } catch (e) {
        onError?.call(e);
        if (!await _waitToRetry(++attempt)) break;
        continue;
      }

      _setStatus(RealtimeStatus.connected);
      attempt = 0;
      await ended.future;
      await _sub?.cancel();
      _sub = null;
      if (_stopped) break;
      if (!await _waitToRetry(++attempt)) break;
    }
    if (!_stopped) _setStatus(RealtimeStatus.disconnected);
  }

  /// Emits disconnected, then sleeps before the next attempt. Returns `false`
  /// if the attempt cap is reached or the channel was stopped meanwhile.
  Future<bool> _waitToRetry(int attempt) async {
    _setStatus(RealtimeStatus.disconnected);
    final cap = maxReconnectAttempts;
    if (cap != null && attempt > cap) return false;
    await _sleep(reconnectBackoff(attempt));
    return !_stopped;
  }

  Future<void> _handle(RealtimeEvent event) async {
    final handler = onEvent;
    if (handler != null) {
      await handler(event);
      return;
    }
    final db = localDb;
    final row = event.row;
    if (db != null && row != null) {
      await db.upsert(event.table, row);
    }
  }

  void _setStatus(RealtimeStatus status) {
    _current = status;
    if (!_status.isClosed) _status.add(status);
  }
}
