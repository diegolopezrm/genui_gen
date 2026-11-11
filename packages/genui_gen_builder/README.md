# genui_gen_builder

[![pub package](https://img.shields.io/pub/v/genui_gen_builder.svg?label=genui_gen_builder&color=0175C2)](https://pub.dev/packages/genui_gen_builder)
[![runtime](https://img.shields.io/pub/v/genui_gen.svg?label=genui_gen&color=0175C2)](https://pub.dev/packages/genui_gen)
[![pub points](https://img.shields.io/pub/points/genui_gen_builder?label=pub%20points)](https://pub.dev/packages/genui_gen_builder/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/diegolopezrm/genui_gen/blob/main/LICENSE)

`build_runner` generator for
[`genui_gen`](https://pub.dev/packages/genui_gen). It turns a Flutter
widget annotated with `@GenUiWidget` into an
[a2ui_flutter](https://pub.dev/packages/a2ui_flutter) component, a
`GenUiComponent`, whose JSON schema, widget builder and examples are all
derived from the widget's constructor. Nothing is written by hand, so the
catalog can never drift from the widget.

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
| renderer | `a2ui_flutter` 0.2.x and 0.3.x, through `genui_gen` 0.15; `genui` 0.10.x, through `genui_gen` 0.14 |

The generator is written against the parts of the analyzer element model that
are stable across major versions, so a new `analyzer` release does not require
a new release of this package unless it removes API the generator uses.

It generates for the renderer the `genui_gen` it resolves is built on.
genui_gen 0.15 declares next to its annotations that it is built on
a2ui_flutter, and gets `GenUiComponent`s and `FunctionImplementation`s; an app
still on genui_gen 0.14 keeps getting genui's `CatalogItem`s and
`ClientFunction`s, unchanged. The rest of this README describes the
a2ui_flutter output.

## Install

```yaml
dependencies:
  a2ui_flutter: ^0.3.0
  genui_gen: ^0.15.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.14.0
```

Add `a2ui_core: ^0.7.0` as well once the app imports it, as rendering with a
`MessageProcessor` does. The generated part shares your file's imports and
names `GenUiComponent`, `GenUiSchemas` and, for lists, maps and data classes,
`S`; `genui_gen` exports all of them, so `json_schema_builder` is not a
dependency of yours.

**The two packages move together.** The builder emits calls to runtime helpers
as they are added, so a new builder against an old runtime generates code that
does not compile. Nothing enforces it for you: the builder deliberately does
not depend on `genui_gen` — it matches the annotations by name, so the
Flutter-dependent runtime never loads into the build isolate.

| Builder | Needs at least | Because it emits |
|---|---|---|
| 0.14.x | `genui_gen >= 0.14.0`, and 0.15.0 for a2ui_flutter | on a2ui_flutter, `GenUiComponent`, `GenUiSchemas`, `genUiWriter` and `genUiMissingIn`; on genui, what 0.13 emits |
| 0.13.x | `genui_gen >= 0.14.0` | the `genui_gen` import in `genui_catalog.g.dart` |
| 0.8.x | `genui_gen >= 0.9.0` | `GenUiClientFunction` |
| 0.7.x | `genui_gen >= 0.8.0` | `genUiTemplateChildren`, `GenUiBinding.value` |
| 0.6.x | `genui_gen >= 0.5.0` | the assembled `Catalog` with its `catalogId` |
| 0.5.x | `genui_gen >= 0.4.0` | `genUiValueWriter` |
| 0.2.x–0.4.x | `genui_gen >= 0.2.0` | the `@GenUiData` decoders |

No `build.yaml` is needed to generate the components: the builder applies
itself to every package that depends on it and writes `<file>.genui.dart` next
to the source. One is needed only for the assembled catalog, which needs an id
(see [The package's catalog](#the-packages-catalog)).

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

The generated part declares `final GenUiComponent productCardCatalogItem`,
ready to be added to a catalog. The variable name is always
`<lowerCamelClassName>CatalogItem`, regardless of `@GenUiWidget(name:)`.

The annotated file must:

- contain the `part '<file>.genui.dart';` directive (the builder warns and
  skips the file otherwise), and
- import `package:genui_gen/genui_gen.dart` (plus Flutter). The generated code
  is a `part of` your library and reuses its imports; when one is missing the
  build fails with the exact import lines to add. `genui_gen` exports every
  renderer type and schema name the generated part uses.

## The package's catalog

A second builder collects every generated component and function of the
package into `lib/genui_catalog.g.dart`, which declares both lists and, with an
id, the assembled catalog:

```dart
final List<GenUiComponent> genUiCatalogItems = <GenUiComponent>[
  productCardCatalogItem,
  statTileCatalogItem,
];

final List<FunctionImplementation> genUiCatalogFunctions =
    <FunctionImplementation>[];

final CatalogImplementation genUiCatalog = CatalogImplementation(
  id: 'com.example.app',
  components: genUiCatalogItems,
  functions: genUiCatalogFunctions,
  instructions: genUiExampleInstructions(genUiCatalogItems),
);
```

The instructions show the agent an example of each component. An app composes
the catalog with the basic one through `basicCatalog().derive(...)`, as the
generated file's doc comment shows. The file is formatted with dart_style, so
it passes `dart format` whatever its names do to the line lengths.

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

Without it there is no `genUiCatalog`, since an a2ui_flutter catalog cannot
exist without an id: the file declares the two lists, and the build warns and
says where to set one. An id that is not a string, or that could not survive
being written into the generated file, is a build error naming the option.

## Lists the data model fills

`@GenUiProp(template: true)` on a `List<Widget>` lets the property accept a
child template — `{"componentId": "row", "path": "/rows"}` — as well as a list
of ids. Its schema is A2UI's `ChildList` instead of a list of component ids,
and a2ui_core expands the template: one child per entry at that path, with the
entry as its own data context, so a new entry adds a child without the agent
composing anything again. Off by default, since it changes the schema the model
composes against.

## Type mapping

| Constructor parameter type | Schema | Read with |
|---|---|---|
| `String`, `String?` | `GenUiSchemas.string` | `props.string(k)` |
| `int`, `double`, `num` (+`?`) | `GenUiSchemas.number` | `props.number(k)`, then `toInt()` for an `int` |
| `bool`, `bool?` | `GenUiSchemas.boolean` | `props.boolean(k)` |
| any `enum` (+`?`) | `GenUiSchemas.string(enumValues: ...)` | `props.string(k)`, then `Enum.values.asNameMap()[s]` |
| `List<String>` (+`?`) | `GenUiSchemas.stringList` | `genUiAsStringList(props.value(k))` |
| `List<int>`, `List<double>`, `List<num>` (+`?`) | `GenUiSchemas.list(items: S.number())` | `genUiAsNumList(props.value(k))`, then `toInt()` / `toDouble()` per entry |
| `List<Enum>` (+`?`) | `GenUiSchemas.list(items: S.string(enumValues: ...))` | `genUiAsStringList(props.value(k))`, then the enum's name map, dropping a name it does not declare |
| `Map<String, V>` (+`?`) | `GenUiSchemas.object(literal: S.object(additionalProperties: <V schema>))` | `genUiAsStringMap`, `genUiAsNumMap`, `genUiAsBoolMap` or `genUiAsObject` on `props.value(k)` |
| `Widget`, `Widget?` | `GenUiSchemas.componentId` | `props.child(k)`, then `buildChild(node)` |
| `List<Widget>` (+`?`) | `GenUiSchemas.componentIdList`, or `GenUiSchemas.childList` with `template: true` | `props.children(k).map(buildChild)` |
| a `@GenUiData` class (+`?`) | `GenUiSchemas.object(literal: <its ObjectSchema>)` | `genUiAsObject(props.value(k))`, then `<name>FromGenUiJson(map, genUiMissingIn(context, node, k))` |
| `List<@GenUiData>` (+`?`) | `GenUiSchemas.list(items: <its ObjectSchema>)` | `genUiAsObjectList(props.value(k))`, then `<name>FromGenUiJson` per entry |
| `VoidCallback`, `void Function()` (+`?`) | `GenUiSchemas.action` | `props.action(k)` |
| `void Function(T)` with `@GenUiWrites('p')` | none | `genUiWriter<T>(context, props, 'p')` |
| a `@GenUiChecked` parameter | `checks`, `GenUiSchemas.checks()` | `props.validationErrors.firstOrNull`, `props.isValid`, or a `GenUiCheckResult` of both |
| `Key? key`, `super.key` | skipped | — |
| anything else | build error | — |

Each schema is one a2ui_core recognises, and that is what makes it resolve the
property before the builder runs: a dynamic value (a literal, a
`{"path": ...}` or a `{"call": ...}`) arrives as a binding `props` reads
through, a `ComponentId` as a child node, an `Action` as a closure, and
`checks` as `isValid` and `validationErrors`. For a data property the binding
applies to the whole object, so `{"path": "/rows"}` resolves the list and the
generated decoder runs on the result, and the schema says so, which is why an
object property is a union of the object schema, a data binding and a function
call rather than the bare object schema. `GenUiSchemas.component` wraps the
properties, adds `accessibility` and `weight`, which every basic component
takes, and allows no other property.

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
  value:
      (genUiAsNum(json['value']) ??
              genUiMissingField<num>(onMissing, 'value', 0))
          .toDouble(),
  trend: Trend.values.asNameMap()[genUiAsString(json['trend'])],
);
```

`ObjectSchema(...)` and not `S.object(...)`: `Schema.object` is a redirecting
factory typed as `Schema`, so it cannot initialise an `ObjectSchema` variable.
Both build exactly the same schema.

Rules specific to data classes:

- Fields use the plain `S.*` schemas, not the dynamic `GenUiSchemas` forms: the
  values inside a data object are literals the model emits, and the binding
  applies to the object as a whole. An `int` field is therefore `S.integer`,
  which a widget property cannot be: A2UI's `DynamicNumber` has no integer
  form.
- Nothing is cast. Every field goes through the `genUiAs*` coercions exported
  by `genui_gen`, so a model that sends `"42"` where a number was declared gets
  42, and a field of the wrong type never throws a `TypeError` inside `build`.
- Supported field types are the scalar set above (`String`, `int`, `double`,
  `num`, `bool`, enums, a `List` of any of those, and a `Map<String, V>`) plus
  nested `@GenUiData` classes and lists of them. A `Widget`, a `List<Widget>`
  or a callback inside a data class is a build error: a data class is data, not
  a component reference.
- Nested schemas are inlined (by referencing the nested `ObjectSchema`
  variable), never `$ref`'d, so a component's schema carries everything it
  needs. A class that reaches itself is therefore a build error naming the
  cycle path.
- A **required** field that is missing or malformed decodes to the same neutral
  fallback the widget builder uses (`''`, `0`, `false`, the first enum value,
  `const []`, a nested object decoded from an empty map), so a malformed row
  degrades instead of throwing inside `build`, and is reported through the
  optional `onMissing` reporter. An **optional** field decodes to `null` (or to
  its Dart default when the constructor declares one) and is never reported.
- The generated widget builder passes `genUiMissingIn(context, node, k)` as
  that reporter. A literal object was checked against the schema when its
  message arrived, so what it catches is bound data with a required field
  missing: the agent gets a `VALIDATION_FAILED` error at `/rows/label`, once
  per component, rather than a silent fallback. While the path holds nothing
  yet, the property falls back to empty and nothing is decoded or reported.
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
  `description` of the union around the object; on a field of another data
  class the nested schema is copied with that description in place of the
  class's own `@GenUiData(description:)`.
- A field with the wire key `event` or `functionCall`, on a class a property
  takes directly, is a build error: a2ui_core would read the object as an
  action and hand the widget a closure. So is a class a property takes a list
  of with both `condition` and `message`, which it would read as checks. A
  class nested inside another keeps any name.

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
  basic component the examples use.
- `@GenUiProp(name: ...)` renames the schema property; names must be unique
  and match `[A-Za-z_][A-Za-z0-9_-]*`.
- `id`, `component`, `accessibility` and `weight` are reserved property names,
  since every component takes them. On a widget with `@GenUiChecked`, so are
  `checks`, `isValid`, `validationErrors`, `validationResults` and
  `validationPending`, where a2ui_core writes what the checks say. Rename the
  wire key with `@GenUiProp(name: ...)`.
- Property descriptions come from, in order: `@GenUiProp(description:)` /
  `@GenUiAction(description:)`, the parameter's `///` doc comment, the backing
  field's `///` doc comment.
- `@GenUiProp` and `@GenUiAction` may be placed on the parameter or, for
  `this.x` parameters, on the field.
- `@GenUiAction(eventName:)` only affects the generated example; the event
  actually dispatched is whatever the model puts in the action data.
- `@GenUiWidget(isImplicitlyFlexible:)` has nothing to set on a2ui_flutter,
  where a basic `Row` or `Column` sizes a child by its `weight`. The builder
  warns rather than dropping it silently.
- Enum values use the Dart constant names verbatim. The enum must be visible
  without an import prefix from the annotated library.

## Required-but-missing values

A required property the agent leaves out never reaches the generated builder:
a2ui_core validates each message against the schema and rejects the component,
and the error is the agent's to see. What does reach it is a property bound to
a path that holds nothing yet. The builder never throws on one: it passes a
neutral fallback (`''`, `0`, `false`, the first enum value, `const []`,
`SizedBox.shrink()`, a no-op callback, a data object decoded from an empty
map) without reporting anything, the way a basic component shows an empty
text, and the widget rebuilds once the data arrives. Bound data is not checked
against the schema, so a required field missing from a bound `@GenUiData`
object is the one thing reported, through `genUiMissingIn`.

## Examples

One example per widget is generated from the schema: required properties plus
the optional ones with an obvious sample (enums, actions, child components,
data objects, strings whose name hints at a URL or e-mail). A data property
gets one sample object and a list property gets two, built from the data
class's own fields by the same rules. Child components reference `Text`
components (ids `child_<prop>`) that are included in the example, so the
examples assume the basic catalog is part of yours.

A property that a `@GenUiWrites` callback writes to is bound to a path named
after it (`{"path": "/enabled"}`) rather than given a literal: only a bound
property can be written, and an agent copies the examples it is shown.

The examples are kept on the `GenUiComponent`, and the generated catalog's
instructions carry them to the agent through `genUiExampleInstructions`.

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

On a2ui_flutter, a reserved property name, a data object a2ui_core would read
as an action and a list it would read as checks are errors that say what to
rename, and `isImplicitlyFlexible` is a warning. A package whose parts were
generated for different renderers is an error from the catalog builder, which
says to regenerate with `--delete-conflicting-outputs`.

## Generated shape

```dart
final GenUiComponent productCardCatalogItem = GenUiComponent(
  name: 'ProductCard',
  schema: GenUiSchemas.component(
    description: 'A product card with price and image.',
    properties: {
      'title': GenUiSchemas.string(description: 'Product name.'),
      'price': GenUiSchemas.number(description: 'Price in USD.'),
      'imageUrl': GenUiSchemas.string(),
      'onTap': GenUiSchemas.action(
        description: 'Fired when the card is tapped.',
      ),
    },
    required: ['title', 'price'],
  ),
  examples: [
    r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Quarterly report",
    "price": 19.99,
    ...
  }
]''',
  ],
  builder: (context, node, props, buildChild) => ProductCard(
    title: props.string('title') ?? '',
    price: props.number('price') ?? 0,
    imageUrl: props.string('imageUrl'),
    onTap: props.action('onTap'),
  ),
);
```

## Testing the builder

The package's own tests run with plain `dart test`; Flutter, genui,
a2ui_flutter and genui_gen are replaced by small in-memory stubs, with a
`genui_gen` built on each renderer, so the generator is exercised without a
Flutter SDK.

## License

MIT. Copyright Diego Alejandro López Camacho.
