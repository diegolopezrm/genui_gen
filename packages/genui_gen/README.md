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
  genui_gen: ^0.1.0
  json_schema_builder: ^0.1.3

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.1.0
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

## Annotations

| Annotation | Target | Purpose |
|---|---|---|
| `@GenUiWidget(description:, name:, constructor:, isImplicitlyFlexible:)` | class | Marks a widget as a catalog component. `description` is required. |
| `@GenUiProp(description:, name:, ignore:)` | parameter or field | Overrides the schema property; `ignore: true` excludes it. |
| `@GenUiAction(eventName:, description:)` | parameter or field | Customizes a `VoidCallback` action. |

Descriptions default to the parameter's doc comment, then the field's doc
comment.

## Runtime helpers

Generated code uses these; you normally do not call them yourself.

- `GenUiBindings` resolves a map of `GenUiBinding`s against a `DataContext`
  and calls a builder once with a `GenUiValues`. It composes genui's
  `BoundString`, `BoundNumber`, `BoundBool` and `BoundList`, so literals,
  `{"path": ...}` data bindings and `{"call": ...}` function calls behave
  exactly as in the core catalog and rebuild when the data model changes.
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

## License

MIT. Copyright Diego Alejandro López Camacho.
