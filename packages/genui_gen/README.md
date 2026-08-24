# genui_gen

Annotations and runtime helpers for generating [genui](https://pub.dev/packages/genui)
`CatalogItem`s from your own Flutter widgets.

Annotate a widget you already have, run `build_runner`, and get a catalog item
whose JSON schema, widget builder and few-shot example are all derived from the
widget's constructor. Because nothing is written by hand, the catalog can never
drift from the widget.

This package is the runtime half of the pair. It contains only the annotations
and a few small helpers used by the generated code. The generator lives in
[`genui_gen_builder`](../genui_gen_builder), which goes in `dev_dependencies`.

## Install

```yaml
dependencies:
  genui: ^0.10.0
  genui_gen: ^0.2.0
  json_schema_builder: ^0.1.3

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.2.0
```

`json_schema_builder` is a direct dependency because the generated part shares
your imports and uses its `S.object(...)` factory.

## Annotate

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

part 'product_card.genui.dart';

@GenUiWidget(description: 'A product card with price and image.')
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    this.imageUrl,
    this.onTap,
  });

  /// Product name.
  final String title;

  /// Price in USD.
  final double price;

  /// Optional image URL.
  final String? imageUrl;

  /// Fired when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => /* ... */ const SizedBox();
}
```

Run `dart run build_runner build` and add the generated item to your catalog:

```dart
final catalog = BasicCatalogItems.asCatalog().copyWith(
  newItems: [productCardCatalogItem],
);
```

The generated examples reference the core `Text` component for child widgets,
so keep genui's basic catalog in the `Catalog` you hand to the controller.

## Structured data with `@GenUiData`

A widget property does not have to be a scalar. Annotate the value object with
`@GenUiData` and the widget can take it, or a list of it, directly.

Before, a table had to be flattened into parallel lists of strings, and the
widget had to zip them back together and hope they were the same length:

```dart
@GenUiWidget(description: 'A comparison table.')
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.labels, // List<String>
    required this.values, // List<String>, parsed by hand
  });
  // ...
}
```

After, the shape the model has to produce is the shape the widget already has:

```dart
/// Direction of a change.
enum Trend { up, down, flat }

@GenUiData(description: 'One row of a comparison table.')
class ComparisonRow {
  const ComparisonRow({required this.label, required this.value, this.trend});

  /// Text shown in the first column.
  final String label;

  /// Numeric value shown in the second column.
  final double value;

  /// Direction of the change, if known.
  final Trend? trend;
}

@GenUiWidget(description: 'A comparison table.')
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({super.key, required this.rows});

  /// The rows to display.
  final List<ComparisonRow> rows;
  // ...
}
```

The generator derives an object schema for `ComparisonRow` from its
constructor, inlines it in the `rows` property (as the item schema of a list
that also accepts a `{"path": ...}` binding), and generates the decoder that
rebuilds each row from the map the model produced. `@GenUiProp` works on a data
class constructor exactly as it does on a widget's.

A data class holds data, not components: its fields may be the scalar types a
widget supports, other `@GenUiData` classes, or lists of them. `Widget` and
callback fields are a build error, and so is a data class that reaches itself,
because schemas are inlined rather than referenced.

## Supported parameter types

| Dart parameter type | Schema emitted | Passed to the constructor as |
|---|---|---|
| `String`, `String?` | `A2uiSchemas.stringReference` | the resolved `String` |
| `int`, `double`, `num` (+`?`) | `A2uiSchemas.numberReference` | converted with `toInt()` / `toDouble()` |
| `bool`, `bool?` | `A2uiSchemas.booleanReference` | the resolved `bool` |
| any `enum` (+`?`) | `A2uiSchemas.stringReference(enumValues: ...)` | `E.values.asNameMap()[value]` |
| `List<String>` (+`?`) | `A2uiSchemas.stringArrayReference` | `List<String>` |
| a `@GenUiData` class (+`?`) | `oneOf` of its object schema, a data binding and a function call | the decoded instance |
| `List<T>` (+`?`) where `T` is `@GenUiData` | `A2uiSchemas.listOrReference(items: <T schema>)` | one decoded `T` per entry |
| `Widget`, `Widget?` | `A2uiSchemas.componentReference` | `ctx.buildChild(id)` |
| `List<Widget>` (+`?`) | list of component references | one `ctx.buildChild` per id |
| `VoidCallback`, `void Function()` (+`?`) | `A2uiSchemas.action` | a callback that dispatches a `UserActionEvent` |
| `Key? key`, `super.key` | skipped | not passed |
| anything else | build error naming the widget, parameter and type | — |

Inside a `@GenUiData` class the field types are the same list minus `Widget`,
`List<Widget>` and callbacks, and the schemas are the plain `S.*` ones
(`S.string`, `S.integer`, `S.number`, `S.boolean`, `S.list`) because the values
in a data object are literals the model emits; the binding applies to the
object as a whole. The full rules live in
[`genui_gen_builder`'s README](../genui_gen_builder#type-mapping).

## Annotations

| Annotation | Target | Purpose |
|---|---|---|
| `@GenUiWidget(description:, name:, constructor:, isImplicitlyFlexible:)` | class | Marks a widget as a catalog component. `description` is required. |
| `@GenUiData(description:, constructor:)` | class | Marks a plain data class a widget property may take. |
| `@GenUiProp(description:, name:, ignore:)` | parameter or field | Overrides the schema property; `ignore: true` excludes it. |
| `@GenUiAction(eventName:, description:)` | parameter or field | Customizes a `VoidCallback` action. |

Descriptions default to the parameter's doc comment, then the field's doc
comment.

## Runtime helpers

Generated code uses these; you normally do not call them yourself.

- `GenUiBindings` resolves a map of `GenUiBinding`s against a `DataContext`
  and calls a builder once with a `GenUiValues`. It composes genui's
  `BoundString`, `BoundNumber`, `BoundBool`, `BoundList` and `BoundObject`, so
  literals, `{"path": ...}` data bindings and `{"call": ...}` function calls
  behave exactly as in the core catalog and rebuild when the data model
  changes. `GenUiValues.object` and `GenUiValues.objectList` expose the
  resolved data objects; a value of the wrong shape reads as `null`, and a
  list entry that is not a map is skipped rather than throwing.
- `GenUiDecoder<T>` is the signature of the generated function that rebuilds a
  `@GenUiData` class from one resolved map.
- `genUiActionHandler(ctx, actionData)` returns a `VoidCallback` that performs
  an A2UI action the way the core `Button` does: `event` actions dispatch a
  `UserActionEvent` with `sourceComponentId` set to the component id, and
  `functionCall` actions resolve through the `DataContext`. Returns `null`
  when the action data is `null`, and never throws. Malformed action data is
  reported as an `A2uiValidationException`, so the model receives the actual
  message.
- `genUiReportMissing(ctx, component, property)` reports a required property
  the model omitted as an `A2uiValidationException`, once per component
  instance. It stays silent for `{"path": ...}` and `{"call": ...}` bindings
  that have not resolved yet, because those rebuild on their own once the
  data model is populated.
- `genUiAsString`, `genUiAsNum`, `genUiAsBool`, `genUiAsStringList`,
  `genUiAsObject` and `genUiAsObjectList` coerce one raw JSON value the way
  genui's `Bound*` widgets coerce a widget property. Generated decoders call
  them instead of casting, so a model that sends a number where a string was
  declared degrades exactly as it would for a widget property rather than
  throwing a `TypeError` inside `build`.
- `GenUiMissingFieldReporter`, `genUiMissingField` and `genUiNestedField` carry
  the same reporting down into a data object: the generated widget builder
  hands the decoder a reporter, so a required field the model left out of a row
  reaches the model as `rows.label` instead of being silently replaced.

## License

MIT. Copyright Diego Alejandro López Camacho.
