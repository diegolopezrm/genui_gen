# genui_gen_builder

[![pub package](https://img.shields.io/pub/v/genui_gen_builder.svg?label=genui_gen_builder&color=0175C2)](https://pub.dev/packages/genui_gen_builder)
[![runtime](https://img.shields.io/pub/v/genui_gen.svg?label=genui_gen&color=0175C2)](https://pub.dev/packages/genui_gen)
[![pub points](https://img.shields.io/pub/points/genui_gen_builder?label=pub%20points)](https://pub.dev/packages/genui_gen_builder/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/diegolopezrm/genui_gen/blob/main/LICENSE)

`build_runner` generator for
[`genui_gen`](https://pub.dev/packages/genui_gen). It turns a Flutter
widget annotated with `@GenUiWidget` into an A2UI `CatalogItem`, rendered by
[a2ui_flutter](https://pub.dev/packages/a2ui_flutter), whose JSON schema,
widget builder and few-shot example are all derived from the widget's
constructor. Nothing is written by hand, so the catalog can never drift from
the widget.

A widget parameter may also be a plain data class annotated with `@GenUiData`,
or a `List` of one, so a table, a chart series or any list of value objects can
be composed by the model. A top-level function annotated with `@GenUiFunction`
becomes a catalog function, which is the other half of a catalog: what the
model computes a value with rather than what it composes a surface out of.

**[What the pair does, on one page →](https://diegolopezrm.github.io/genui_gen/)**

## Compatibility

| | Supported |
|---|---|
| Dart SDK | `>=3.10.0 <4.0.0` |
| `analyzer` | `>=10.0.0 <15.0.0` |
| `a2ui_core` (generated code) | `0.5.x` |
| `a2ui_flutter` (generated code) | `0.1.x` |

The generator is written against the parts of the analyzer element model that
are stable across major versions, so a new `analyzer` release does not require
a new release of this package unless it removes API the generator uses.

## Install

```yaml
dependencies:
  a2ui_flutter: ^0.1.0
  genui_gen: ^0.14.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.13.0
```

The generated part builds its schema with `S.object(...)` and shares your
file's imports, and `genui_gen` re-exports `S`, `Schema` and `ObjectSchema` for
that, so `json_schema_builder` is not a dependency of yours.

**The two packages move together.** The builder emits calls to runtime helpers
as they are added, so a new builder against an old runtime generates code that
does not compile. Nothing enforces it for you: the builder deliberately does
not depend on `genui_gen` — it matches the annotations by name, so the
Flutter-dependent runtime never loads into the build isolate.

| Builder | Needs at least | Because it emits |
|---|---|---|
| unreleased | the matching unreleased `genui_gen` | a2ui_flutter components: `CatalogItem(schema:, builder:)`, `CommonSchemas`, `genUiWrittenValue` |
| 0.8.x | `genui_gen >= 0.9.0` | `GenUiClientFunction` |
| 0.7.x | `genui_gen >= 0.8.0` | `genUiTemplateChildren`, `GenUiBinding.value` |
| 0.6.x | `genui_gen >= 0.5.0` | the assembled `Catalog` with its `catalogId` |
| 0.5.x | `genui_gen >= 0.4.0` | `genUiValueWriter` |
| 0.2.x–0.4.x | `genui_gen >= 0.2.0` | the `@GenUiData` decoders |

No `build.yaml` is needed to generate the items: the builder applies itself to
every package that depends on it and writes `<file>.genui.dart` next to the
source. One is needed only to give the assembled catalog an id — see
[The package's catalog](#the-packages-catalog).

## Use

```dart
// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:genui_gen/genui_gen.dart';

part 'product_card.genui.dart';

@GenUiWidget(description: 'A product card with price and image.')
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    /// Product name.
    required this.title,
    /// Price in USD.
    required this.price,
    this.imageUrl,
    /// Fired when the card is tapped.
    this.onTap,
  });

  final String title;
  final double price;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => /* ... */;
}
```

```sh
dart run build_runner build
```

The generated part declares `final CatalogItem productCardCatalogItem`, ready
to be added to a `CatalogImplementation`. The variable name is always
`<lowerCamelClassName>CatalogItem`, regardless of `@GenUiWidget(name:)`.

The annotated file must:

- contain the `part '<file>.genui.dart';` directive (the builder warns and
  skips the file otherwise), and
- import `package:genui_gen/genui_gen.dart` (plus Flutter). The generated code
  is a `part of` your library and reuses its imports; when one is missing the
  build fails with the exact import lines to add. `genui_gen` re-exports `S`,
  `Schema`, `ObjectSchema` and the a2ui_core and a2ui_flutter names the
  generated part uses, so they come with it.

## The package's catalog

A second builder collects every generated item of the package into
`lib/genui_catalog.g.dart`, which declares both the list and the assembled
`CatalogImplementation`:

```dart
final List<CatalogItem> genUiCatalogItems = <CatalogItem>[
  productCardCatalogItem,
  statTileCatalogItem,
];

final CatalogImplementation genUiCatalog = CatalogImplementation(
  id: 'com.example.app',
  components: genUiCatalogItems,
  functions: genUiCatalogFunctions,
);
```

The id comes from `build.yaml`, because it names the catalog to the agent that
composes against it and to the clients that render it — not something a
generator can invent:

```yaml
targets:
  $default:
    builders:
      genui_gen_builder:genui_catalog:
        options:
          catalog_id: com.example.app
```

Without it only the lists are written, because an A2UI catalog cannot exist
without an id, and the generated file says how to set one. An id that is not a string, or that could
not survive being written into the generated file, is a build error naming the
option.

## Lists the data model fills

`@GenUiProp(template: true)` on a `List<Widget>` lets the property accept a
child template — `{"componentId": "row", "path": "/rows"}` — as well as a list
of ids. One child is built per entry at that path, with the entry as its own
data context, and a new entry adds a child without the agent composing
anything again. Off by default, since it changes the schema the model composes
against.

## Type mapping

| Constructor parameter type | Schema | Read with |
|---|---|---|
| `String`, `String?` | `CommonSchemas.dynamicString` | `genUiAsString(props.value(k))` |
| `int`, `double`, `num` (+`?`) | `CommonSchemas.dynamicNumber` | `genUiAsNum(props.value(k))`, then `toInt()` / `toDouble()` |
| `bool`, `bool?` | `CommonSchemas.dynamicBoolean` | `genUiAsBool(props.value(k))` |
| any `enum` (+`?`) | `S.combined(anyOf: [S.string(enumValues: ...), dataBinding, functionCall])` | `genUiAsString(props.value(k))`, then `Enum.values.asNameMap()[s]` |
| `List<String>` (+`?`) | `CommonSchemas.dynamicStringList` | `genUiAsStringList(props.value(k))` |
| `Widget`, `Widget?` | `CommonSchemas.componentId` | `buildChild` on `props.child(k)` |
| `List<Widget>` (+`?`) | `S.list(items: CommonSchemas.componentId)` | `buildChild` on each of `props.children(k)` |
| a `@GenUiData` class (+`?`) | `S.combined(anyOf: [<its ObjectSchema>, dataBinding, functionCall])` | `genUiAsObject(props.value(k))`, then `<name>FromGenUiJson(map)` |
| `List<@GenUiData>` (+`?`) | `S.combined(anyOf: [S.list(items: <its ObjectSchema>), dataBinding, functionCall])` | `genUiAsObjectList(props.value(k))`, then `.map(<name>FromGenUiJson)` |
| `VoidCallback`, `void Function()` (+`?`) | `CommonSchemas.action` | `genUiActionHandler(props.action(k))` |
| `Key? key`, `super.key` | skipped | — |
| anything else | build error | — |

The renderer resolves each property from its schema, so every one accepts a
literal, a `{"path": ...}` and a `{"call": ...}`, exactly like the core
catalog's. For a data property the binding applies to the whole object, so
`{"path": "/rows"}` resolves the list and the generated decoder runs on the
result — and the schema says so, which is why an object property is an `anyOf`
of the object schema, a data binding and a function call rather than the bare
object schema. `anyOf` rather than `oneOf`, because a binding is an object too
and matches an object schema with no required fields as well.

## Data classes

```dart
// lib/models/row.dart
part 'row.genui.dart';

@GenUiData(description: 'One row of the table.')
class Row {
  const Row({required this.label, required this.value, this.trend});

  /// Row label.
  final String label;

  /// Row value.
  final double value;
  final Trend? trend;
}
```

generates, into the same part file the widgets of that library use:

```dart
/// Generated schema for [Row].
final ObjectSchema rowGenUiSchema = ObjectSchema(
  description: 'One row of the table.',
  properties: {
    'label': S.string(description: 'Row label.'),
    'value': S.number(description: 'Row value.'),
    'trend': S.string(enumValues: ['up', 'down', 'flat']),
  },
  required: ['label', 'value'],
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
factory typed as `Schema`, so it cannot initialise an `ObjectSchema` variable.
Both build exactly the same schema.

Rules specific to data classes:

- Fields use the plain `S.*` schemas, not `CommonSchemas.dynamic*`: the values
  inside a data object are literals the model emits, and the binding applies to
  the object as a whole. An `int` field is therefore `S.integer`, which a
  widget property cannot be — `CommonSchemas` only offers `dynamicNumber`.
- Nothing is cast. Every field goes through the `genUiAs*` coercions exported
  by `genui_gen`, which apply the very rules the generated builder applies to
  a widget property, so a model that sends `"42"` where a number was declared
  degrades identically in both places and never throws a `TypeError` inside
  `build`.
- Supported field types are the scalar set above (`String`, `int`, `double`,
  `num`, `bool`, enums, `List<String>`) plus nested `@GenUiData` classes and
  lists of them. A `Widget`, a `List<Widget>` or a callback inside a data class
  is a build error: a data class is data, not a component reference.
- Nested schemas are inlined (by referencing the nested `ObjectSchema`
  variable), never `$ref`'d, because the catalog document holds the
  component's schema as it is and there is no registry entry to point a `$ref`
  at. A class that reaches itself is therefore
  a build error naming the cycle path.
- A **required** field that is missing or malformed decodes to the same neutral
  fallback the widget builder uses (`''`, `0`, `false`, the first enum value,
  `const []`, a nested object decoded from an empty map), so a malformed row
  degrades instead of throwing inside `build`, and is reported through the
  optional `onMissing` reporter. An **optional** field decodes to `null` (or to
  its Dart default when the constructor declares one) and is never reported.
- The generated widget builder passes that reporter, so a required field the
  model left out of a row reaches the model as `rows.label` through
  `genUiReportMissing`, not as a silent fallback. It passes it only on the
  branch where the property actually resolved: a `{"path": ...}` on the whole
  object that has not resolved yet is reported once as the bare property (and
  `genUiReportMissing` stays silent for a pending binding) instead of
  producing one `<property>.<field>` error per required field.
- `@GenUiProp(name:)`, `@GenUiProp(description:)` and `@GenUiProp(ignore:)`
  apply to constructor parameters of a data class unchanged, and
  `@GenUiData(constructor:)` picks a named constructor.
- The generated names are `<lowerCamelClassName>GenUiSchema` and
  `<lowerCamelClassName>FromGenUiJson`.
- The few-shot example for a `List<@GenUiData>` property holds two entries
  that deliberately differ: required strings are numbered (`Sample label 1`,
  `Sample label 2`), numbers are spread (`42`/`43`, `42.5`/`43.5`) and enum
  fields walk the enum instead of repeating the first value, so the example
  shows the model that every field varies from row to row. A standalone
  object property is entry 0 and keeps the same sample values 0.1 used.
- A doc comment or `@GenUiProp(description:)` on a property whose type is a
  data class is kept, so one use site can explain what the object means there
  without changing the shared class. On a widget property it becomes the
  `description` of the `oneOf` wrapper; on a field of another data class the
  nested schema is copied with that description in place of the class's own
  `@GenUiData(description:)`.

A widget in one file may use a data class declared in another. The generated
part names the schema and decoder as plain identifiers, so the library
declaring the widget must import the one declaring the data class **without a
prefix** and without a `show` / `hide` combinator that filters out
`<name>GenUiSchema` and `<name>FromGenUiJson`, and that library must declare its
own `part '<file>.genui.dart';`. All three are checked, and the build fails with
the missing piece named rather than emitting code that does not resolve.

A data class keeps a constructor parameter called `key`: unlike a widget it has
no `super.key` to skip, so `key` is an ordinary field and stays in the schema.

## Rules

- A property is `required` in the schema iff the parameter is `required` in
  the constructor, has no default value and is non-nullable.
- Parameters with a default value are optional in the schema; when the value
  is absent the Dart default applies (the generated code emits
  `?? <default>`).
- `@GenUiProp(ignore: true)` leaves a parameter out. It must then be optional
  or have a default, otherwise the build fails. An ignored positional
  parameter must not be followed by another positional parameter, because the
  later one would shift into its slot.
- A `super.x` parameter whose default is inherited from a superclass in
  another library is accepted only when that default is a plain literal;
  otherwise redeclare it as `this.x = <default>` or ignore it.
- The annotated class must be a concrete `Widget`. Private classes need an
  explicit `@GenUiWidget(name: ...)`, and the name `Text` is reserved for the
  core catalog item the examples use.
- `@GenUiProp(name: ...)` renames the schema property; names must be unique
  and match `[A-Za-z_][A-Za-z0-9_-]*`.
- Property descriptions come from, in order: `@GenUiProp(description:)` /
  `@GenUiAction(description:)`, the parameter's `///` doc comment, the backing
  field's `///` doc comment.
- `@GenUiProp` and `@GenUiAction` may be placed on the parameter or, for
  `this.x` parameters, on the field.
- `@GenUiAction(eventName:)` only affects the generated example; the event
  actually dispatched is whatever the model puts in the action data.
- Enum values use the Dart constant names verbatim. The enum must be visible
  without an import prefix from the annotated library.

## Required-but-missing values

The generated builder never throws. When a required property is missing or
resolves to `null` it substitutes a neutral fallback (`''`, `0`, `false`, the
first enum value, `const []`, `SizedBox.shrink()`, a no-op callback, a data
object decoded from an empty map) and calls
`genUiReportMissing`, which reports a `VALIDATION_FAILED` error on the
surface's `onError` once per component instance, so the model gets the feedback
and the surface still renders. The renderer checks every component against its
schema before the builder runs, so most of what the model leaves out is
rejected and reported there first. Unresolved `{"path": ...}` and `{"call": ...}`
bindings are not reported: they rebuild on their own once the data arrives.

## Examples

One example per widget is generated from the schema: required properties plus
the optional ones with an obvious sample (enums, actions, child components,
data objects, strings whose name hints at a URL or e-mail). A data property
gets one sample object and a list property gets two, built from the data
class's own fields by the same rules. Child components reference
`Text` components (ids `child_<prop>`) that are included in the example, so
the examples assume the basic catalog's components are part of your catalog.

## Diagnostics

All problems are reported as `InvalidGenerationSourceError` pointing at the
offending class or parameter: unsupported types (with the hint to use
`@GenUiProp(ignore: true)`), an empty description, `ignore` on a required
parameter or on a positional one that others would shift into, an unknown
named constructor, `@GenUiAction` on a non-callback, duplicate or invalid
property names, non-Widget or abstract classes, two classes whose lower-camel
names collide, inherited non-literal defaults, prefixed enums and missing
imports (mentioning prefixed imports when that is the cause). For data classes:
a `Widget` or callback field, a cycle (with the path), no usable constructor, a
class carrying both `@GenUiWidget` and `@GenUiData`, a generic data class, a
field whose wire key would be the reserved `path` or `call`, two data classes
whose generated names collide at the use site, a data class that is not visible
unprefixed, whose library has no generated part or that is imported with a
`show` / `hide` combinator hiding its generated declarations, and an unannotated
class of your own used as a parameter (the message names it and asks for
`@GenUiData`). A parameter whose type does not resolve at all is reported as
such — the cause is a missing import or an ambiguous name, not the type table.

## Generated shape

```dart
final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  schema: S.object(
    description: 'A product card with price and image.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'Product name.',
      }),
      'price': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description': 'Price in USD.',
      }),
      'imageUrl': CommonSchemas.dynamicString,
      'onTap': S.fromMap({
        ...CommonSchemas.action.value,
        'description': 'Fired when the card is tapped.',
      }),
    },
    required: ['title', 'price'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Sample title",
    "price": 42.5,
    ...
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'ProductCard', property);
      return fallback;
    }

    return ProductCard(
      title:
          genUiAsString(props.value('title')) ?? missing<String>('title', ''),
      price: (genUiAsNum(props.value('price')) ?? missing<num>('price', 0))
          .toDouble(),
      imageUrl: genUiAsString(props.value('imageUrl')),
      onTap: genUiActionHandler(props.action('onTap')),
    );
  },
);
```

## Testing the builder

The package's own tests run with plain `dart test`; Flutter, a2ui_core,
a2ui_flutter and genui_gen are replaced by small in-memory stubs so the
generator is exercised without a Flutter SDK.

## License

MIT. Copyright Diego Alejandro López Camacho.
