import 'package:flutter_universal_sync_core/flutter_universal_sync_core.dart';

/// A [ConflictResolver] implementing an **LWW-Element-Map** CRDT: each field is
/// an independent last-write-wins register keyed by a per-field timestamp.
///
/// Unlike whole-row last-write-wins (which loses one side entirely), this keeps
/// *both* edits when two devices change *different* fields, and resolves a
/// genuine same-field conflict by the larger timestamp (deterministic
/// stringwise tiebreak on equal timestamps). The merge is **commutative,
/// associative, and idempotent** — the CRDT guarantee — so every replica
/// converges regardless of the order changes arrive.
///
/// Per-field timestamps live in the [clockField] sub-map. Stamp a row's clock
/// with [stamp] whenever you write locally; rows without a clock fall back to
/// the row's [timestampField] for every field.
class LwwMapResolver implements ConflictResolver {
  /// Creates a resolver. [timestampField] is the row-level fallback clock and
  /// [clockField] is the embedded per-field timestamp sub-map.
  const LwwMapResolver({
    this.timestampField = SyncColumns.updatedAt,
    this.clockField = '_lww',
  });

  /// Row-level fallback timestamp used when a field has no per-field entry.
  final String timestampField;

  /// The sub-map holding `{field: timestampMs}`.
  final String clockField;

  /// Returns a copy of [row] with every (non-clock, non-id) field stamped at
  /// [timestamp] — call this on each local write so per-field LWW works.
  Map<String, dynamic> stamp(Map<String, dynamic> row, DateTime timestamp) {
    final ms = timestamp.toUtc().millisecondsSinceEpoch;
    final clock = Map<String, int>.from(_clockOf(row));
    for (final key in row.keys) {
      if (key == clockField || key == SyncColumns.id) continue;
      clock[key] = ms;
    }
    return {...row, clockField: clock};
  }

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final lClock = _clockOf(local);
    final rClock = _clockOf(remote);
    final lFallback = (local[timestampField] as num?)?.toInt() ?? 0;
    final rFallback = (remote[timestampField] as num?)?.toInt() ?? 0;

    final fields = <String>{...local.keys, ...remote.keys}..remove(clockField);
    final merged = <String, dynamic>{};
    final mergedClock = <String, int>{};

    for (final f in fields) {
      final inL = local.containsKey(f);
      final inR = remote.containsKey(f);
      final lt = lClock[f] ?? lFallback;
      final rt = rClock[f] ?? rFallback;

      if (inL && !inR) {
        merged[f] = local[f];
        mergedClock[f] = lt;
      } else if (inR && !inL) {
        merged[f] = remote[f];
        mergedClock[f] = rt;
      } else {
        final remoteWins =
            rt != lt ? rt > lt : '${remote[f]}'.compareTo('${local[f]}') >= 0;
        merged[f] = remoteWins ? remote[f] : local[f];
        mergedClock[f] = rt > lt ? rt : lt;
      }
    }

    merged[clockField] = mergedClock;
    return merged;
  }

  Map<String, int> _clockOf(Map<String, dynamic> row) {
    final c = row[clockField];
    if (c is Map) {
      return {
        for (final e in c.entries) '${e.key}': (e.value as num).toInt(),
      };
    }
    return const {};
  }
}
