/// Encodes/decodes between plain Dart values and Firestore's typed-value
/// JSON (`{stringValue: ...}`, `{integerValue: "..."}`, etc.).
///
/// Covers the JSON-able types a synced row uses: null, bool, int, double,
/// String, `List`, and nested `Map<String, dynamic>`. Firestore's
/// `timestampValue`/`bytesValue`/`referenceValue`/`geoPointValue` are out of
/// scope for the v1 skeleton.
class FirestoreValueCodec {
  const FirestoreValueCodec._();

  /// Encodes a row map to `{field: typedValue}`.
  static Map<String, dynamic> encodeFields(Map<String, dynamic> row) =>
      row.map((k, v) => MapEntry(k, encodeValue(v)));

  /// Decodes `{field: typedValue}` back to a plain row map.
  static Map<String, dynamic> decodeFields(Map<String, dynamic> fields) =>
      fields.map((k, v) => MapEntry(k, decodeValue(v as Map<String, dynamic>)));

  /// Encodes one value to its Firestore typed representation.
  static Map<String, dynamic> encodeValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encodeValue).toList()},
      };
    }
    if (value is Map) {
      return {
        'mapValue': {
          'fields': value.map(
            (k, v) => MapEntry(k as String, encodeValue(v)),
          ),
        },
      };
    }
    throw ArgumentError.value(value, 'value', 'unsupported Firestore type');
  }

  /// Decodes one Firestore typed value back to a plain Dart value.
  static Object? decodeValue(Map<String, dynamic> typed) {
    if (typed.containsKey('nullValue')) return null;
    if (typed.containsKey('booleanValue')) return typed['booleanValue'] as bool;
    if (typed.containsKey('integerValue')) {
      return int.parse(typed['integerValue'] as String);
    }
    if (typed.containsKey('doubleValue')) {
      return (typed['doubleValue'] as num).toDouble();
    }
    if (typed.containsKey('stringValue')) return typed['stringValue'] as String;
    if (typed.containsKey('arrayValue')) {
      final values =
          (typed['arrayValue'] as Map)['values'] as List? ?? const [];
      return values.map((v) => decodeValue(v as Map<String, dynamic>)).toList();
    }
    if (typed.containsKey('mapValue')) {
      final fields =
          (typed['mapValue'] as Map)['fields'] as Map<String, dynamic>? ??
              const {};
      return decodeFields(fields);
    }
    throw ArgumentError.value(typed, 'typed', 'unknown Firestore value');
  }
}
