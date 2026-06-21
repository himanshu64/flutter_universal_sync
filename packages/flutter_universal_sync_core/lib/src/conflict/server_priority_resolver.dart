import 'conflict_resolver.dart';

/// Always picks the remote row; discards local edits on conflict.
class ServerPriorityResolver implements ConflictResolver {
  /// Creates the resolver.
  const ServerPriorityResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) =>
      remote;
}
