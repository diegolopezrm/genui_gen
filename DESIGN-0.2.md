# genui_gen 0.2 — objects and lists of objects

## The gap 0.1 leaves

`GenUiBinding` only expresses `string`, `number`, `bool` and `stringList`. So
`@GenUiWidget` works for widgets whose constructor takes scalars, and fails the
build for anything that takes structured data. That rules out the widgets people
actually want an LLM to compose: a table (`List<Row>`), a chart series
(`List<Point>`), a list of items, a widget taking a value object.

0.2 closes exactly that: **a widget parameter may be an annotated data class, or
a `List` of one.**

## New public API — `package:genui_gen/genui_gen.dart`

```dart
/// Marks a plain Dart class as a data shape an annotated widget may receive.
///
/// The generator derives a JSON Schema from the chosen constructor (same rules
/// as `@GenUiWidget`) and a decoder that rebuilds the instance from the map the
/// model produced.
class GenUiData {
  const GenUiData({this.description, this.constructor});
  final String? description;
  final String? constructor;
}
```

`@GenUiProp` already exists and applies unchanged to data-class constructor
parameters (`description`, `name`, `ignore`).

Runtime additions:

```dart
/// Decodes one already-resolved JSON map into `T`.
typedef GenUiDecoder<T> = T Function(Map<String, Object?> json);

/// Reports one required field of a data object that was missing or unusable.
typedef GenUiMissingFieldReporter = void Function(String field);

/// Coercions matching genui's Bound* converters, called by generated decoders
/// in place of a cast.
String? genUiAsString(Object? value);
num? genUiAsNum(Object? value);
bool? genUiAsBool(Object? value);
List<String>? genUiAsStringList(Object? value);
Map<String, Object?>? genUiAsObject(Object? value);
List<Map<String, Object?>>? genUiAsObjectList(Object? value);

/// Reports `field` through `onMissing` (if any) and returns `fallback`.
T genUiMissingField<T>(
  GenUiMissingFieldReporter? onMissing,
  String field,
  T fallback,
);

/// A reporter for the fields of the nested object held by `field`.
GenUiMissingFieldReporter? genUiNestedField(
  GenUiMissingFieldReporter? onMissing,
  String field,
);

sealed class GenUiBinding {
  // existing: string / number / bool / stringList
  const factory GenUiBinding.object(Object? raw) = _ObjectBinding;
  const factory GenUiBinding.objectList(Object? raw) = _ObjectListBinding;
}

class GenUiValues {
  // existing: string / number / boolean / stringList
  Map<String, Object?>? object(String key);
  List<Map<String, Object?>>? objectList(String key);
}
```

`GenUiBindings` folds `object` through genui's `BoundObject` and `objectList`
through `BoundList`, so `{"path": ...}` and `{"call": ...}` resolve with genui's
own semantics — the same rule 0.1 follows. Decoding happens after resolution, in
generated code, never inside the runtime.

## Type mapping added in 0.2

| Dart parameter type | Schema | Builder |
|---|---|---|
| `T` where `T` is `@GenUiData` (+nullable) | `S.combined(oneOf: [<T schema>, A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()])` | `GenUiBinding.object` → `T.fromGenUiJson(map)` |
| `List<T>` where `T` is `@GenUiData` (+nullable) | `A2uiSchemas.listOrReference(items: <T schema>)` | `GenUiBinding.objectList` → `.map(T.fromGenUiJson).toList()` |

The property schema is a union, not the bare object schema: the builder folds
the value through `BoundObject` / `BoundList`, which resolve `{"path": ...}`
and `{"call": ...}` as well as a literal, so the schema has to allow all three
or a data-bound table fails validation for a surface the runtime would have
rendered. The core catalog declares comparable properties the same way
(`ChoicePicker.options` uses `listOrReference`, `ChoicePicker.value` a
`oneOf` of the literal, `dataBindingSchema()` and `functionCall()`).

Inside a `@GenUiData` class the supported field types are the 0.1 scalar set —
`String`, `int`, `double`, `num`, `bool`, enums, `List<String>` — plus nested
`@GenUiData` classes and `List<@GenUiData>`. Widgets and callbacks are NOT valid
inside a data class (a data class is data the model emits, not a component
reference); attempting it is a build error naming the field.

Nested data schemas are inlined, not `$ref`'d: `CatalogItem.dataSchema` is
consumed by `A2uiSchemas.updateComponentsSchema` as a `oneOf` branch, and a
`$ref` would need a registry entry we do not control.

## Generated output for a data class

For `@GenUiData class Row { const Row({required this.label, required this.value, this.trend}); ... }`
in `lib/models/row.dart` with `part 'row.genui.dart';`:

```dart
/// Generated schema for [Row].
final ObjectSchema rowGenUiSchema = ObjectSchema(
  description: '...',
  properties: {
    'label': S.string(description: '...'),
    'value': S.number(description: '...'),
    'trend': S.string(description: '...', enumValues: ['up','down','flat']),
  },
  required: ['label','value'],
);

/// Decodes a [Row] from the map the model produced.
Row rowFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => Row(
  label:
      genUiAsString(json['label']) ??
      genUiMissingField<String>(onMissing, 'label', ''),
  value: (genUiAsNum(json['value']) ??
          genUiMissingField<num>(onMissing, 'value', 0))
      .toDouble(),
  trend: Trend.values.asNameMap()[genUiAsString(json['trend'])],
);
```

`ObjectSchema(...)` and not `S.object(...)`: `Schema.object` is a redirecting
factory statically typed as `Schema`, so it cannot initialise the
`ObjectSchema` variable the generated code declares. Both build the same
schema. `int` fields use `S.integer`, which a widget property cannot (there is
no `integerReference` in `A2uiSchemas`), so a fractional value is rejected by
validation instead of being silently truncated.

Note the schema for a data class uses plain `S.string` / `S.number`, NOT
`A2uiSchemas.stringReference`: values inside a data object are literals the
model emits, not per-field data bindings. The binding applies to the whole
object (the widget property), which is what `BoundObject` resolves.

No value is cast. Every field goes through the `genUiAs*` coercions the runtime
exports, which apply the same rules genui's `Bound*` widgets apply to a widget
property, so a model that sends `"42"` where a number was declared degrades
identically in both places and a wrong-typed field never throws a `TypeError`
inside `build`.

Missing **required** fields inside a data object fall back to the same defaults
as 0.1 (`''`, `0`, `false`, first enum value, `const []`) and are reported: the
decoder takes an optional `GenUiMissingFieldReporter`, and the generated widget
builder passes one that forwards to `genUiReportMissing` with the property
prefixed, so the model is told about `rows.label` rather than a bare `label`.
Optional fields decode to `null` (or to the Dart default the constructor
declares) and are never reported.

The reporter is handed to the decoder only when the property itself resolved.
When a `{"path": ...}` on the whole object has not resolved yet — the ordinary
case where the component update arrives before the data model update — the
property is reported once by `missing<T>()`, which stays silent for a pending
binding, and the empty fallback is decoded without a reporter. Otherwise the
model would receive one false `<property>.<field>` error per required field of
a component it never got wrong.

## Cycles

A data class that reaches itself (directly or transitively) is a build error
naming the cycle path. Inlined schemas cannot express recursion.

## Rejected at build time

Beyond cycles, a `@GenUiData` class is rejected when:

- it has type parameters — an inlined JSON Schema cannot express one, and the
  decoder can only name the bare class;
- a field's wire key would be `path` or `call` — genui resolves a map with a
  String `path` as a data binding and one containing `call` as a function call,
  so such an object never reaches the widget as a literal;
- two data classes used by the same generated part have colliding lower-camel
  names (`HTTPRow` and `HttpRow` both give `httpRowGenUiSchema`), even when
  they live in different libraries;
- the library that uses it imports the declaring library with a `show` / `hide`
  combinator that lets the class through but filters out
  `<name>GenUiSchema` / `<name>FromGenUiJson`.

Unlike a widget, a data class keeps a constructor parameter called `key`: there
is no `super.key` to skip, so dropping it would generate a decoder that does
not compile.

## Compatibility

Additive. Every 0.1 widget generates byte-identical output. Version 0.2.0,
`genui_gen` and `genui_gen_builder` released together.

## Quality bar

Unchanged from 0.1: `dart analyze` clean, `dart format` clean, pana 160/160,
tests green for every new path, example app updated to demonstrate a table
widget driven by `List<Row>`, no tool attribution anywhere.
