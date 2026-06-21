import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// Programmable [RemoteSyncAdapter] for tests.
class FakeRemoteSyncAdapter implements RemoteSyncAdapter {
  /// Calls to [pushOperation], in arrival order. Inspected by tests.
  final List<SyncQueueEntry> pushed = [];

  /// Each pushChange call pops the head of [pushOutcomes]. If the
  /// queue is empty, the call succeeds. To make a call throw, push an
  /// [Exception] (or any [Object]) here.
  final List<Object?> pushOutcomes = [];

  /// Per-pull-call canned responses, keyed by table. Each list is
  /// drained head-first; once empty, subsequent calls return `[]`.
  final Map<String, List<List<Map<String, dynamic>>>> pullResponses = {};

  /// Records of (table, since) pairs the engine asked for.
  final List<({String table, DateTime? since})> pullCalls = [];

  /// Optional artificial delay applied to each [pushChange]. Useful
  /// for testing concurrency / coalescing.
  Duration pushDelay = Duration.zero;

  @override
  Future<void> pushChange(SyncQueueEntry entry) async {
    pushed.add(entry);
    if (pushDelay > Duration.zero) {
      await Future<void>.delayed(pushDelay);
    }
    if (pushOutcomes.isEmpty) return;
    final outcome = pushOutcomes.removeAt(0);
    if (outcome != null) {
      throw outcome;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullChanges(
    String table,
    DateTime? since,
  ) async {
    pullCalls.add((table: table, since: since));
    final canned = pullResponses[table];
    if (canned == null || canned.isEmpty) return const [];
    return canned.removeAt(0);
  }
}
