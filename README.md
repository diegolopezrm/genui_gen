# genui_gen

Annotate a Flutter widget, run `build_runner`, get a genui `CatalogItem` whose
schema, builder and examples are derived from the widget's constructor.

## The problem

A [genui](https://pub.dev/packages/genui) `Catalog` needs three things per
widget: a JSON schema the model composes against, a `widgetBuilder` that turns
that JSON back into a widget, and example data for development tooling and
few-shot prompting. Writing them by hand is tedious, and it drifts silently:
rename a constructor parameter, add a required one, change an enum, and the app
still compiles while the model keeps composing against an outdated contract.
genui's own README is explicit that the model will not use a custom widget on
its own; you are expected to apply prompt-engineering techniques such as
one-shot or few-shot prompting to teach it how and when to use each
`CatalogItem` you add.

## Why derived beats hand-written

`genui_gen` reads the annotated constructor with the analyzer and emits the
`CatalogItem` from it. The schema property names are the parameter names. The
required list is the set of non-nullable parameters without defaults. Enum
values are the enum's `name`s. The builder calls the constructor with every
property resolved through genui's own binding helpers. There is no second
source of truth to keep in sync: if the constructor changes and the generated
part is stale, the build fails or the regenerated file changes in review. The
catalog cannot drift from the widget because the catalog is a function of the
widget.

## 60-second quickstart

### 1. Add the dependencies

```yaml
dependencies:
  genui: ^0.10.0
  genui_gen: ^0.1.0
  json_schema_builder: ^0.1.3

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.1.0
```

`json_schema_builder` is a direct dependency because the generated code is a
`part` of your file and uses its `S.object(...)` factory through your imports.

### 2. Annotate a widget

`lib/widgets/product_card.dart`:

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
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            if (imageUrl != null) Image.network(imageUrl!),
            Text(title),
            Text('\$$price'),
          ],
        ),
      ),
    );
  }
}
```

The `part` directive names the file the generator will write. The generated
part shares your imports, so the annotated file must import `genui`,
`genui_gen` and `json_schema_builder`.

### 3. Generate

```sh
dart run build_runner build
```

### 4. Register the item

```dart
final catalog = BasicCatalogItems.asCatalog().copyWith(
  newItems: [productCardCatalogItem],
);

final controller = SurfaceController(catalogs: [catalog]);
```

### What gets generated

`product_card.genui.dart` (trimmed):

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'product_card.dart';

final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  dataSchema: S.object(
    description: 'A product card with price and image.',
    properties: {
      'title': A2uiSchemas.stringReference(description: 'Product name.'),
      'price': A2uiSchemas.numberReference(description: 'Price in USD.'),
      'imageUrl': A2uiSchemas.stringReference(
        description: 'Optional image URL.',
      ),
      'onTap': A2uiSchemas.action(
        description: 'Fired when the card is tapped.',
      ),
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
    "imageUrl": "https://example.com/sample.png",
    "onTap": {
      "event": {
        "name": "onTap"
      }
    }
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    // Reports a required property the model omitted via ctx.reportError
    // (once per component) and returns the fallback instead.
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

Every property accepts a literal or a genui data binding (`{"path": ...}`)
because `GenUiBindings` composes genui's `BoundString`, `BoundNumber`,
`BoundBool` and `BoundList` under the hood. Actions dispatch a
`UserActionEvent` exactly the way genui's core `Button` does.

## Supported parameter types

| Dart parameter type | Schema emitted | Passed to the constructor as |
|---|---|---|
| `String`, `String?` | string reference | the resolved `String` |
| `int`, `double`, `num` and nullable variants | number reference | converted with `toInt()` / `toDouble()` as needed |
| `bool`, `bool?` | boolean reference | the resolved `bool` |
| `enum E`, `E?` | string reference with `enumValues` set to the enum's `name`s | `E.values.byName(value)` |
| `List<String>`, `List<String>?` | string array reference | `List<String>` |
| `Widget`, `Widget?` | component reference | `ctx.buildChild(id)` |
| `List<Widget>`, `List<Widget>?` | list of component references | one `ctx.buildChild` per id |
| `VoidCallback`, `void Function()` and nullable variants | action | a callback that dispatches a `UserActionEvent` |
| `Key? key` / `super.key` | skipped | not passed |
| anything else | build error naming the widget, parameter and type | see Limitations |

### Required, optional, defaults

- A property is listed in the schema's `required` array only when the
  parameter is `required`, has no default value and is non-nullable.
- A parameter with a default value is optional. The builder passes the
  resolved value only when it is non-null, so the Dart default applies when
  the model omits it.
- A required property that arrives missing or malformed does not throw during
  build. The builder substitutes a fallback (`''`, `0`, `false`, the first enum
  value, `const []`, `SizedBox.shrink()`, a no-op callback) and reports the
  problem once per component through `ctx.reportError`, as an
  `A2uiValidationException` so the model sees the widget and property names.
  A `{"path": ...}` binding that has not resolved yet is not reported; it
  rebuilds on its own when the data model is populated.
- The generated examples use the core `Text` component for child widgets, so
  keep `BasicCatalogItems` in your `Catalog` (as in step 4).

### Where descriptions come from

For each property, the first of these that exists wins:

1. `@GenUiProp(description: ...)` on the parameter.
2. The parameter's own `///` doc comment.
3. The doc comment on the field the parameter initializes (`this.title`).

The widget description is `@GenUiWidget.description`, and it is required: a
catalog entry without a description is useless to the model.

### Annotation reference

```dart
@GenUiWidget(
  description: 'Fed to the model. Required.',
  name: 'ProductCard',          // schema component name; defaults to the class name
  constructor: 'fromSummary',   // named constructor to read; defaults to the unnamed one
  isImplicitlyFlexible: false,  // forwarded to CatalogItem.isImplicitlyFlexible
)
```

```dart
@GenUiProp(
  description: 'Overrides the doc comment.',
  name: 'image_url',            // schema property name; defaults to the parameter name
  ignore: true,                 // leave this parameter out of the schema entirely
)
```

An ignored parameter must be optional or have a default; ignoring a required
parameter is a build error because the builder would have nothing to pass. An
ignored positional parameter must be the last positional one (or be followed
only by ignored ones), otherwise later arguments would shift into its slot.

`@GenUiProp` and `@GenUiAction` may be placed on the constructor parameter or,
for `this.x` parameters, on the field.

```dart
@GenUiAction(
  eventName: 'addToCart',       // UserActionEvent name; defaults to the parameter name
  description: 'Fired when the user adds the product to the cart.',
)
```

`@GenUiAction` is only valid on `VoidCallback` / `void Function()` parameters.

## Limitations (0.1)

Not supported yet; each produces a build error that names the parameter:

- Nested objects and maps (`Map<String, Object?>`, your own data classes).
- Lists other than `List<String>` and `List<Widget>` (`List<int>`, `List<E>`).
- Records.
- Callbacks with arguments (`ValueChanged<T>`, `void Function(String)`).

Two ways around it in the meantime:

- `@GenUiProp(ignore: true)` on the parameter, as long as it is optional or has
  a default. The model never sees it and the widget uses its default.
- Write a thin adapter widget whose constructor only takes supported types,
  have it build the real widget, and annotate the adapter. The adapter is the
  contract the model sees; the real widget stays untouched.

## Roadmap

- 0.2: nested objects and lists of numbers; an aggregating builder that emits
  a single `genui_catalog.g.dart` with every generated item in the package.
- 0.3: smarter example generation (descriptions and enum context feeding the
  sample values instead of fixed `42` / `Sample <name>` placeholders).

## Compatibility

- `genui ^0.10.0`
- Flutter `>=3.35.0`
- Dart `>=3.10.0 <4.0.0`
- `build_runner ^2.15.0`, `source_gen ^4.0.0`, `analyzer >=8.0.0 <11.0.0`

genui lives in [flutter/genui](https://github.com/flutter/genui) and is
pre-1.0; its `CatalogItem`, `A2uiSchemas` and binding APIs still move between
minor versions. This package tracks genui and bumps its constraint when genui
breaks. If you are on a newer genui than the constraint allows, open an issue.

## Packages

| Package | Put it in | What it holds |
|---|---|---|
| [`genui_gen`](packages/genui_gen) | `dependencies` | `@GenUiWidget`, `@GenUiProp`, `@GenUiAction` and the runtime helpers the generated code calls |
| [`genui_gen_builder`](packages/genui_gen_builder) | `dev_dependencies` | the `build_runner` generator |
| [`example`](example) | - | four annotated widgets rendered offline through genui's `DebugCatalogView` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

Diego Alejandro López Camacho
