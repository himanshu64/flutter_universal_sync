import 'conflict_resolver.dart';

/// Always picks the local row; discards remote edits on conflict.
class ClientPriorityResolver implements ConflictResolver {
  /// Creates the resolver.
  const ClientPriorityResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) =>
      local;
}
