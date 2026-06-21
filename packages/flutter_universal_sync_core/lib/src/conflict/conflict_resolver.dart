/// Strategy for reconciling two concurrent row versions for the same id.
///
/// Invocation is the sync engine's responsibility (Plan 2); this contract
/// is pure — given [local] and [remote] maps, return the merged map.
/// If the strategy is deterministic, [resolve] must not have side effects.
abstract class ConflictResolver {
  /// Returns the merged row that should replace both sides.
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  );
}
