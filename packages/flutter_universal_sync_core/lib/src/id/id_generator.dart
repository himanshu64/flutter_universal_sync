import 'package:uuid/uuid.dart';

/// Generator for stable, unique row identifiers.
///
/// The default implementation ([UuidV4Generator]) produces RFC 4122 v4 UUIDs.
/// Tests can inject a deterministic generator to make assertions on ids.
abstract class IdGenerator {
  /// Returns a new unique identifier.
  String nextId();
}

/// Produces UUIDv4 identifiers via `package:uuid`.
class UuidV4Generator implements IdGenerator {
  /// Creates a generator. Inject [uuid] in tests for deterministic output.
  UuidV4Generator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String nextId() => _uuid.v4();
}
