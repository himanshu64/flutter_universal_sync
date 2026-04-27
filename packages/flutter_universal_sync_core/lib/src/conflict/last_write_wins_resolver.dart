import 'conflict_resolver.dart';

/// Chooses whichever row has the later `updated_at`. On an exact tie,
/// returns [remote] so the result is deterministic even with clock skew.
///
/// Accepts [DateTime], ISO-8601 strings, or `int` millisSinceEpoch for the
/// `updated_at` field. Throws [ArgumentError] if the field is missing or
/// typed unexpectedly — conflict data without timestamps is a bug upstream.
class LastWriteWinsResolver implements ConflictResolver {
  /// Creates the resolver.
  const LastWriteWinsResolver();

  @override
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final l = _toUtc(local['updated_at'], side: 'local');
    final r = _toUtc(remote['updated_at'], side: 'remote');
    return l.isAfter(r) ? local : remote;
  }

  DateTime _toUtc(Object? value, {required String side}) {
    if (value == null) {
      throw ArgumentError.value(
        value,
        '$side.updated_at',
        'updated_at is required for conflict resolution',
      );
    }
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) return DateTime.parse(value).toUtc();
    throw ArgumentError.value(
      value,
      '$side.updated_at',
      'Unsupported type for updated_at (got ${value.runtimeType})',
    );
  }
}
