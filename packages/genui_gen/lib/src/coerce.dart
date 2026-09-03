/// Coercions and reporting helpers used by the generated decoders.
///
/// A widget property goes through genui's `Bound*` widgets, which coerce
/// rather than throw: `BoundString` calls `toString()`, `BoundNumber` parses a
/// numeric string, `BoundBool` accepts `"true"` / `"false"` and treats a
/// non-zero number as `true`. The values *inside* a `@GenUiData` object never
/// pass through those widgets, so the same rules are applied here. A model
/// that sends `"42.5"` where a number is expected therefore degrades the same
/// way in both places, and a malformed field never throws inside `build`.
library;

/// Reports one field of a data object that was required but missing or
/// unusable.
///
/// Generated decoders take one of these as an optional second argument; the
/// generated widget builder passes a closure that forwards to
/// `genUiReportMissing` with the property name prefixed, so the model sees
/// `rows.label` rather than a bare `label`.
typedef GenUiMissingFieldReporter = void Function(String field);

/// [value] as a `String`, or `null` when it is `null`.
///
/// Matches genui's `BoundString.convert`: anything that is not already a
/// `String` is rendered with `toString()`.
String? genUiAsString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// [value] as a `num`, or `null` when it cannot be read as one.
///
/// Matches genui's `BoundNumber.convert`: a numeric `String` is parsed, and
/// anything else that is not already a `num` gives `null`.
num? genUiAsNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// [value] as a `bool`, or `null` when it cannot be read as one.
///
/// Matches genui's `BoundBool.convert`: `"true"` / `"false"` (in any case) are
/// parsed, a `num` is `true` when it is not zero, and anything else gives
/// `null`.
bool? genUiAsBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final String lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    return null;
  }
  if (value is num) return value != 0;
  return null;
}

/// [value] as a `List<String>`, or `null` when it is not a list.
///
/// Matches the `stringList` binding: `null` entries are dropped and every
/// other entry is rendered with `toString()`.
List<String>? genUiAsStringList(Object? value) {
  if (value is! List) return null;
  return List<String>.unmodifiable(<String>[
    for (final Object? element in value)
      if (element != null) element.toString(),
  ]);
}

/// [value] as a `List<num>`, or `null` when it is not a list.
///
/// Matches the `numberList` binding: entries that are not numbers are dropped,
/// and a numeric string is parsed.
List<num>? genUiAsNumList(Object? value) {
  if (value is! List) return null;
  return List<num>.unmodifiable(<num>[
    for (final Object? element in value)
      if (element is num)
        element
      else if (element is String && num.tryParse(element) != null)
        num.parse(element),
  ]);
}

/// [value] as a JSON object, or `null` when it is not a map.
///
/// A `Map` with any key type is rebuilt as a `Map<String, Object?>`, so a
/// plain Dart map written into the data model by host code reads the same way
/// as one that came from `jsonDecode`.
Map<String, Object?>? genUiAsObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key.toString(): entry.value,
    };
  }
  return null;
}

/// [value] as a list of JSON objects, or `null` when it is not a list.
///
/// Entries that are not maps are skipped rather than reported: the model can
/// emit junk inside an otherwise valid list, and dropping the bad entries
/// keeps the good ones usable.
List<Map<String, Object?>>? genUiAsObjectList(Object? value) {
  if (value is! List) return null;
  final List<Map<String, Object?>> objects = <Map<String, Object?>>[];
  for (final Object? element in value) {
    final Map<String, Object?>? object = genUiAsObject(element);
    if (object != null) objects.add(object);
  }
  return List<Map<String, Object?>>.unmodifiable(objects);
}

/// Reports [field] through [onMissing], if any, and returns [fallback].
///
/// Generated decoders call this in place of a bare `??` fallback for a
/// required field, so a row the model sent without its `label` still decodes
/// to a usable object *and* tells the model what was wrong.
T genUiMissingField<T>(
  GenUiMissingFieldReporter? onMissing,
  String field,
  T fallback,
) {
  onMissing?.call(field);
  return fallback;
}

/// A reporter for the fields of the nested object held by [field].
///
/// Returns `null` when [onMissing] is `null`, so nothing is allocated when
/// nobody is listening.
GenUiMissingFieldReporter? genUiNestedField(
  GenUiMissingFieldReporter? onMissing,
  String field,
) {
  if (onMissing == null) return null;
  return (String nested) => onMissing('$field.$nested');
}
