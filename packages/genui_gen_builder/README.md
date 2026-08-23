# genui_gen_builder

`build_runner` generator for [`genui_gen`](../genui_gen). It turns a Flutter
widget annotated with `@GenUiWidget` into a genui `CatalogItem` whose JSON
schema, widget builder and few-shot example are all derived from the widget's
constructor. Nothing is written by hand, so the catalog can never drift from
the widget.

## Install

```yaml
dependencies:
  genui: ^0.10.0
  genui_gen: ^0.1.0
  json_schema_builder: ^0.1.3 # provides the `S` schema alias used by genui

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.1.0
```

No `build.yaml` is needed in your app: the builder applies itself to every
package that depends on it and writes `<file>.genui.dart` next to the source.

## Use

```dart
// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

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
to be added to a `Catalog`. The variable name is always
`<lowerCamelClassName>CatalogItem`, regardless of `@GenUiWidget(name:)`.

The annotated file must:

- contain the `part '<file>.genui.dart';` directive (the builder warns and
  skips the file otherwise), and
- import `package:genui/genui.dart`, `package:genui_gen/genui_gen.dart` and
  `package:json_schema_builder/json_schema_builder.dart` (plus Flutter). The
  generated code is a `part of` your library and reuses its imports; when one
  is missing the build fails with the exact import lines to add.

## Type mapping

| Constructor parameter type | Schema | Resolved with |
|---|---|---|
| `String`, `String?` | `A2uiSchemas.stringReference` | `GenUiBinding.string` |
| `int`, `double`, `num` (+`?`) | `A2uiSchemas.numberReference` | `GenUiBinding.number`, then `toInt()` / `toDouble()` |
| `bool`, `bool?` | `A2uiSchemas.booleanReference` | `GenUiBinding.bool` |
| any `enum` (+`?`) | `A2uiSchemas.stringReference(enumValues: ...)` | `GenUiBinding.string`, then `Enum.values.asNameMap()[s]` |
| `List<String>` (+`?`) | `A2uiSchemas.stringArrayReference` | `GenUiBinding.stringList` |
| `Widget`, `Widget?` | `A2uiSchemas.componentReference` | `ctx.buildChild(id)` |
| `List<Widget>` (+`?`) | `S.list(items: componentReference())` | `ids.map(ctx.buildChild)` |
| `VoidCallback`, `void Function()` (+`?`) | `A2uiSchemas.action` | `genUiActionHandler(ctx, data[k])` |
| `Key? key`, `super.key` | skipped | — |
| anything else | build error | — |

Values resolved through `GenUiBindings` accept genui's literal,
`{"path": ...}` and `{"call": ...}` forms, exactly like the core catalog.

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
first enum value, `const []`, `SizedBox.shrink()`, a no-op callback) and calls
`genUiReportMissing`, which reports an `A2uiValidationException` through
`ctx.reportError` once per component instance, so the model gets the feedback
and the surface still renders. Unresolved `{"path": ...}` and `{"call": ...}`
bindings are not reported: they rebuild on their own once the data arrives.

## Examples

One example per widget is generated from the schema: required properties plus
the optional ones with an obvious sample (enums, actions, child components,
strings whose name hints at a URL or e-mail). Child components reference
`Text` components (ids `child_<prop>`) that are included in the example, so
the examples assume genui's `BasicCatalogItems` are part of your `Catalog`.

## Diagnostics

All problems are reported as `InvalidGenerationSourceError` pointing at the
offending class or parameter: unsupported types (with the hint to use
`@GenUiProp(ignore: true)`), an empty description, `ignore` on a required
parameter or on a positional one that others would shift into, an unknown
named constructor, `@GenUiAction` on a non-callback, duplicate or invalid
property names, non-Widget or abstract classes, two classes whose lower-camel
names collide, inherited non-literal defaults, prefixed enums and missing
imports (mentioning prefixed imports when that is the cause).

## Generated shape

```dart
final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  dataSchema: S.object(
    description: 'A product card with price and image.',
    properties: {
      'title': A2uiSchemas.stringReference(description: 'Product name.'),
      'price': A2uiSchemas.numberReference(description: 'Price in USD.'),
      'imageUrl': A2uiSchemas.stringReference(),
      'onTap': A2uiSchemas.action(description: 'Fired when the card is tapped.'),
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'ProductCard', property);
      return fallback;
    }
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'price': GenUiBinding.number(data['price']),
        'imageUrl': GenUiBinding.string(data['imageUrl']),
      },
      builder: (context, v) => ProductCard(
        title: v.string('title') ?? missing<String>('title', ''),
        price: (v.number('price') ?? missing<num>('price', 0)).toDouble(),
        imageUrl: v.string('imageUrl'),
        onTap: genUiActionHandler(ctx, data['onTap']),
      ),
    );
  },
);
```

## Testing the builder

The package's own tests run with plain `dart test`; Flutter, genui and
genui_gen are replaced by small in-memory stubs so the generator is exercised
without a Flutter SDK.

## License

MIT. Copyright Diego Alejandro López Camacho.
