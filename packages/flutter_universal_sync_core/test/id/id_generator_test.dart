import 'package:flutter_universal_sync_core/src/id/id_generator.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/data.dart';

final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('UuidV4Generator', () {
    test('produces a valid RFC 4122 v4 UUID', () {
      final id = UuidV4Generator().nextId();
      expect(
        id,
        matches(_uuidRegex),
        reason: '$id is not a valid v4 UUID',
      );
    });

    test('two consecutive ids are different', () {
      final gen = UuidV4Generator();
      expect(gen.nextId(), isNot(equals(gen.nextId())));
    });

    test('accepts an injected Uuid for deterministic tests', () {
      final fixed = const Uuid().v5(Namespace.url.value, 'fixed-seed');
      final gen = UuidV4Generator(uuid: _StubUuid(fixed));
      expect(gen.nextId(), fixed);
    });
  });
}

class _StubUuid extends Uuid {
  _StubUuid(this._value);
  final String _value;
  @override
  String v4({
    @Deprecated('use config instead. Removal in 5.0.0')
    Map<String, dynamic>? options,
    V4Options? config,
  }) =>
      _value;
}
