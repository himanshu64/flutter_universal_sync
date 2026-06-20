import 'dart:async';

import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';
import 'package:meta/meta.dart';

import '../connectivity/connectivity_monitor.dart';
import '../pull/pull_pipeline.dart';
import '../push/push_pipeline.dart';
import '_clock.dart';
import 'backoff.dart';
import 'sync_state_snapshot.dart';
import 'table_config.dart';

/// Sync engine for the flutter_universal_sync family. Drives the
/// hybrid (auto + explicit) drain loop, exposes a state-snapshot
/// stream, owns push and pull pipelines.
///
/// See `docs/superpowers/specs/2026-04-30-sync-engine-design.md`.
class SyncEngine {
  /// Public constructor. The engine uses a system clock internally.
  SyncEngine({
    required LocalDatabaseAdapter localDb,
    required RemoteSyncAdapter remote,
    required ConnectivityMonitor connectivity,
    required Map<String, TableConfig> tables,
    Duration drainInterval = const Duration(minutes: 5),
    Duration Function(int retryCount) backoff = defaultBackoff,
    IdGenerator? idGenerator,
  }) : this._withClock(
          localDb: localDb,
          remote: remote,
          connectivity: connectivity,
          tables: Map.unmodifiable(tables),
          drainInterval: drainInterval,
          backoff: backoff,
          idGenerator: idGenerator ?? UuidV4Generator(),
          clock: Clock.systemClock,
        );

  /// Test-only constructor that injects a [Clock]. Mark the call site
  /// with `@visibleForTesting` if you call this from outside the engine
  /// package.
  @visibleForTesting
  SyncEngine.withClock({
    required LocalDatabaseAdapter localDb,
    required RemoteSyncAdapter remote,
    required ConnectivityMonitor connectivity,
    required Map<String, TableConfig> tables,
    required Clock clock,
    Duration drainInterval = const Duration(minutes: 5),
    Duration Function(int retryCount) backoff = defaultBackoff,
    IdGenerator? idGenerator,
  }) : this._withClock(
          localDb: localDb,
          remote: remote,
          connectivity: connectivity,
          tables: Map.unmodifiable(tables),
          drainInterval: drainInterval,
          backoff: backoff,
          idGenerator: idGenerator ?? UuidV4Generator(),
          clock: clock,
        );

  SyncEngine._withClock({
    required this.localDb,
    required this.remote,
    required this.connectivity,
    required this.tables,
    required this.drainInterval,
    required this.backoff,
    required this.idGenerator,
    required this.clock,
  })  : _push = PushPipeline(
          localDb: localDb,
          remote: remote,
          clock: clock,
          backoff: backoff,
        ),
        _pull = PullPipeline(localDb: localDb, remote: remote),
        _stateController = StreamController<SyncStateSnapshot>.broadcast() {
    _current = SyncStateSnapshot.idle(pendingCount: 0);
  }

  /// The local database adapter the engine drives. Public so tests and
  /// subclasses can introspect; not part of the typical user-facing API.
  final LocalDatabaseAdapter localDb;

  /// The remote sync adapter the engine drives.
  final RemoteSyncAdapter remote;

  /// Connectivity monitor; the engine subscribes on `start()`.
  final ConnectivityMonitor connectivity;

  /// Per-table configuration: conflict resolver and (future) options.
  final Map<String, TableConfig> tables;

  /// How often the auto-drain loop fires when running.
  final Duration drainInterval;

  /// Backoff function applied to failed pushes.
  final Duration Function(int retryCount) backoff;

  /// ID generator (currently unused inside the engine; reserved for
  /// future internal IDs and exposed so DI containers can wire one
  /// instance across packages).
  final IdGenerator idGenerator;

  /// Clock — system clock in production, fake clock in tests.
  @visibleForTesting
  final Clock clock;

  final PushPipeline _push;
  final PullPipeline _pull;
  final StreamController<SyncStateSnapshot> _stateController;
  late SyncStateSnapshot _current;
  bool _disposed = false;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _started = false;

  /// Snapshot stream. Broadcast; late subscribers immediately receive
  /// the current snapshot.
  ///
  /// Implemented with [Stream.multi] so each subscriber synchronously
  /// hooks the underlying controller on listen *before* the current
  /// snapshot is delivered — a plain `async*` generator would subscribe
  /// only after yielding `current`, racing (and dropping) any snapshot
  /// emitted in that gap.
  Stream<SyncStateSnapshot> get state {
    if (_disposed) return const Stream<SyncStateSnapshot>.empty();
    return Stream<SyncStateSnapshot>.multi((controller) {
      controller.add(_current);
      final sub = _stateController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  /// Synchronous accessor for non-stream consumers.
  SyncStateSnapshot get current => _current;

  /// Starts the auto-drain loop. Idempotent.
  Future<void> start() async {
    if (_disposed) {
      throw StateError('SyncEngine.start called after dispose');
    }
    if (_started) return;
    _started = true;

    _connectivitySub = connectivity.onChange.listen((online) {
      if (online) {
        unawaited(_scheduleCycle(pull: false));
      }
    });
    _timer = Timer.periodic(drainInterval, (_) {
      unawaited(_scheduleCycle(pull: false));
    });

    if (connectivity.isOnline) {
      unawaited(_scheduleCycle(pull: false));
    }
  }

  /// Stops the auto-drain loop. Awaits any in-flight cycle. Idempotent.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // _runCycle already handles its own errors; ignore.
      }
    }
  }

  /// Explicit trigger. Runs a drain cycle.
  ///
  /// `pull: false` (default) → push only.
  /// `pull: true` → push, then pull every registered table.
  ///
  /// Concurrent calls coalesce: if a cycle is already in flight, the
  /// returned Future resolves when that cycle completes.
  Future<void> syncNow({bool pull = false}) {
    if (_disposed) {
      throw StateError('SyncEngine.syncNow called after dispose');
    }
    return _scheduleCycle(pull: pull);
  }

  Future<void> _scheduleCycle({required bool pull}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _runCycle(pull: pull);
    _inFlight = future;
    future.whenComplete(() {
      _inFlight = null;
    });
    return future;
  }

  Future<void> _runCycle({required bool pull}) async {
    if (_disposed) return;
    if (!connectivity.isOnline) {
      _emit(await _snapshotIdle());
      return;
    }
    _emit(await _snapshotSyncing());
    Object? lastError;
    try {
      final pushResult = await _push.drain();
      if (pushResult.failed.isNotEmpty) {
        lastError = pushResult.failed.last.error;
      }
      if (pull) {
        for (final entry in tables.entries) {
          try {
            await _pull.pullTable(entry.key, entry.value);
          } catch (e) {
            lastError = e;
          }
        }
      }
    } catch (e) {
      lastError = e;
    }
    if (lastError == null) {
      _emit(
        (await _snapshotIdle()).copyWith(
          lastSyncedAt: clock.now(),
          clearLastError: true,
        ),
      );
    } else {
      _emit(
        SyncStateSnapshot.error(
          pendingCount: await _countPending(),
          lastError: lastError.toString(),
          lastSyncedAt: _current.lastSyncedAt,
        ),
      );
    }
  }

  Future<SyncStateSnapshot> _snapshotIdle() async => SyncStateSnapshot.idle(
        pendingCount: await _countPending(),
        lastSyncedAt: _current.lastSyncedAt,
      );

  Future<SyncStateSnapshot> _snapshotSyncing() async =>
      SyncStateSnapshot.syncing(
        pendingCount: await _countPending(),
        lastSyncedAt: _current.lastSyncedAt,
      );

  Future<int> _countPending() async {
    final pending = await localDb.pendingSyncEntries();
    return pending.length;
  }

  /// Disposes the engine. Cancels timer and connectivity subscription,
  /// closes the snapshot stream, marks the engine unusable. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // _runCycle handles its own errors; ignore.
      }
    }
    await _stateController.close();
  }

  /// Emits a new snapshot on the stream and updates [current]. Internal
  /// to the engine; pipelines call this via the cycle loop.
  void _emit(SyncStateSnapshot snapshot) {
    _current = snapshot;
    if (!_stateController.isClosed) {
      _stateController.add(snapshot);
    }
  }
}
