# genui_gen — Design

Annotation-driven `CatalogItem` generation for Google's `genui` package.
You annotate a widget you already have; `build_runner` derives the JSON schema,
the widget builder, and the few-shot examples from its constructor. Because
everything is derived, the catalog can never drift from the widget.

## Packages (Dart workspace)

| Package | Role | Dependencies |
|---|---|---|
| `packages/genui_gen` | Annotations + tiny runtime helpers used by generated code | `flutter`, `genui`, `meta` |
| `packages/genui_gen_builder` | `build_runner` generator (`source_gen`) | `analyzer`, `build`, `source_gen` (the annotation is matched by name so the Flutter-dependent `genui_gen` never loads into the build isolate) |
| `example/` | Flutter app with 4 annotated widgets, wired into a `Catalog` | both |

Mirrors the `json_annotation` / `json_serializable` convention. Users add
`genui_gen` to `dependencies` and `genui_gen_builder` to `dev_dependencies`.

Target: Dart `>=3.10.0 <4.0.0`, Flutter `>=3.35.0`, `genui ^0.10.0`,
`source_gen ^4.0.0`, `analyzer >=8.0.0 <11.0.0`, `build ^4.0.0`.
The generator MUST use the current analyzer element model (`ClassElement`,
`ConstructorElement`, `FormalParameterElement`, `EnumElement`, etc. — the
post-`element2` API). Verify against the cached sources in
`~/.pub-cache/hosted/pub.dev/source_gen-4.2.4` and `analyzer-10.2.0`.

## Public API — `package:genui_gen/genui_gen.dart`

```dart
/// Marks a widget class as a GenUI catalog component.
class GenUiWidget {
  const GenUiWidget({
    this.name,                 // defaults to the class name
    required this.description, // fed to the LLM; required on purpose
    this.constructor,          // named constructor to use; default unnamed
    this.isImplicitlyFlexible = false,
  });
}

/// Per-parameter overrides. Optional; doc comments are the default source.
/// Targets: parameter, or the backing field of a `this.x` parameter.
class GenUiProp {
  const GenUiProp({this.description, this.name, this.ignore = false});
}

/// Marks a `void Function()` / `VoidCallback` parameter as a user action.
/// `eventName` defaults to the parameter name (e.g. `onTap`).
/// Targets: parameter, or the backing field of a `this.x` parameter.
class GenUiAction {
  const GenUiAction({this.eventName, this.description});
}
```

Runtime helpers (also exported; used by generated code only):

```dart
/// Resolves a set of literal-or-bound values against a DataContext and calls
/// [builder] once with all of them resolved. Internally composes genui's
/// BoundString / BoundNumber / BoundBool / BoundList so binding semantics
/// ({"path": ...}, {"call": ...}, literal) are exactly genui's.
class GenUiBindings extends StatelessWidget {
  const GenUiBindings({
    required this.dataContext,
    required this.bindings,           // Map<String, GenUiBinding>
    required this.builder,            // Widget Function(BuildContext, GenUiValues)
  });
}

sealed class GenUiBinding {
  const factory GenUiBinding.string(Object? raw) = ...;
  const factory GenUiBinding.number(Object? raw) = ...;
  const factory GenUiBinding.bool(Object? raw) = ...;
  const factory GenUiBinding.stringList(Object? raw) = ...;
}

/// Typed accessors over resolved values.
class GenUiValues {
  static const GenUiValues empty;
  String? string(String key);
  num? number(String key);
  bool? boolean(String key);
  List<String>? stringList(String key);
  Object? operator [](String key);   // raw resolved value
  bool has(String key);              // resolved to non-null
  Iterable<String> get keys;
}

/// Builds a VoidCallback that dispatches a UserActionEvent the same way the
/// core Button does (supports the `event` form of A2UI actions; `functionCall`
/// is resolved through dataContext like Button does). Malformed action data
/// is reported as an A2uiValidationException (the only error type genui
/// forwards to the model with its message intact).
VoidCallback? genUiActionHandler(CatalogItemContext ctx, Object? actionData);

/// Reports a required property the model omitted as an
/// A2uiValidationException(surfaceId, path: property), once per
/// `surfaceId/componentId/property`. Silent for `{"path"}` / `{"call"}`
/// bindings that have not resolved yet. Never throws.
void genUiReportMissing(CatalogItemContext ctx, String component, String property);
```

## Type mapping (v0.1)

| Dart parameter type | Schema | Resolution in builder |
|---|---|---|
| `String` / `String?` | `A2uiSchemas.stringReference(description:)` | `GenUiBinding.string` → `values.string(k)` |
| `int`, `double`, `num` (+nullable) | `A2uiSchemas.numberReference(description:)` | `GenUiBinding.number` → `.toInt()` / `.toDouble()` as needed |
| `bool` / `bool?` | `A2uiSchemas.booleanReference(description:)` | `GenUiBinding.bool` |
| `enum E` / `E?` | `A2uiSchemas.stringReference(description:, enumValues: E.values names)` | `GenUiBinding.string` → `E.values.byName(s)` |
| `List<String>` (+nullable) | `A2uiSchemas.stringArrayReference(description:)` | `GenUiBinding.stringList` |
| `Widget` / `Widget?` | `A2uiSchemas.componentReference(description:)` | `ctx.buildChild(id)` (wrapped in `KeyedSubtree`? no — plain) |
| `List<Widget>` (+nullable) | `S.list(items: A2uiSchemas.componentReference())` | `ids.map(ctx.buildChild).toList()` |
| `VoidCallback` / `void Function()` (+nullable) | `A2uiSchemas.action(description:)` | `genUiActionHandler(ctx, data[k])` |
| `Key? key` / `super.key` | skipped silently | — |
| anything else | **build error** with a clear message naming the widget, parameter and type, and suggesting `@GenUiProp(ignore: true)` | — |

Rules:
- A parameter is `required` in the schema iff it is `required` in the
  constructor AND has no default value AND is non-nullable.
- Parameters with a default value are optional; the generated builder passes
  the resolved value only when non-null (so the Dart default applies).
- `@GenUiProp(ignore: true)` excludes the parameter; it must then be optional or
  have a default, otherwise build error. An ignored (or `key`) positional
  parameter followed by a non-ignored positional parameter is a build error,
  because the later argument would shift into its slot.
- Default values are emitted after `??` / `:` wrapped in parentheses unless
  they are a single literal, identifier or plain `const` expression.
- `super.x` parameters inherit the superclass default source; when the
  superclass is in another library only plain literals are accepted (other
  identifiers may not resolve in the generated part), otherwise build error.
- The class must be a concrete subtype of `Widget`. Private classes need an
  explicit `name`; the name `Text` is rejected (reserved for the core item the
  examples reference); two classes whose lower-camel names collide are
  rejected.
- Property description precedence: `@GenUiProp.description` > the parameter's
  doc comment (`///`) > the corresponding field's doc comment > none.
- Description of the widget itself: `@GenUiWidget.description` (required).
- Enum values use the Dart enum `name`s verbatim.
- Schema property names default to the Dart parameter names; `@GenUiProp.name`
  overrides.

## Generated code shape

Input: `lib/widgets/product_card.dart` with `part 'product_card.genui.dart';`.
Output: `product_card.genui.dart` (a `part of`), containing one top-level
`final CatalogItem <lowerCamel>CatalogItem` per annotated class, e.g.
`productCardCatalogItem`, plus a convenience `const List<CatalogItem>
genUiCatalogItems` is NOT generated per file (collision); instead each file
exposes its items and the user assembles the `Catalog`. (A future aggregating
builder can produce `genui_catalog.g.dart`.)

Generated structure (illustrative):

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
      'imageUrl': A2uiSchemas.stringReference(description: 'Optional image URL.'),
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
    "imageUrl": "https://example.com/sample.png",
    "onTap": {"event": {"name": "onTap"}}
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

The example JSON is emitted as an indented raw multi-line string so the
generated file stays readable and within 80 columns.

Required-but-missing values: generator emits a fallback (`''`, `0`, `false`,
first enum value, `const []`, `const SizedBox.shrink()`, a no-op callback)
through a local `missing<T>()` helper that calls `genUiReportMissing`, which
reports an `A2uiValidationException` via `ctx.reportError` once per component
instance and ignores unresolved data bindings — never throws inside build.

Example JSON generation: one example per widget. Values: strings → a short
sample derived from the property description or `"Sample <name>"`; numbers →
`42` (ints) / `42.5` (doubles); bools → `true`; enums → first value; child
widgets → reference a `Text` component included in the example list; lists of
widgets → two `Text` children; actions → `{"event": {"name": "<eventName>"}}`.
Child component ids are `child_<prop>` / `child_<prop>_<n>` so they never
collide with `root`. Only required props + nullable props with obvious samples
are included. The examples assume genui's `BasicCatalogItems` are in the
catalog.

## Builder wiring

`build.yaml` in `genui_gen_builder`:
```yaml
builders:
  genui_gen:
    import: "package:genui_gen_builder/builder.dart"
    builder_factories: ["genUiGenBuilder"]
    build_extensions: {".dart": [".genui.dart"]}
    auto_apply: dependents
    build_to: source
```
Decision (implemented): `PartBuilder([GenUiGenerator()], '.genui.dart')` with
`build_to: source`, `auto_apply: dependents`. No combining builder needed.

Diagnostics must be `InvalidGenerationSourceError` with `element:` set so
build_runner points at the right line.

## Tests (`packages/genui_gen_builder/test`)

Use `source_gen_test`-style golden tests or `build_test`'s `testBuilder`:
- `string_props_test` — required/optional/nullable strings, doc comments.
- `numbers_and_bools_test` — int/double/num/bool, defaults.
- `enum_test` — enumValues and byName mapping.
- `children_test` — `Widget`, `Widget?`, `List<Widget>`.
- `actions_test` — `VoidCallback`, `@GenUiAction(eventName:)`.
- `errors_test` — unsupported type, missing description, ignore on required.
- `runtime_test` (in `genui_gen/test`) — `GenUiBindings` resolves literals and
  `{"path": ...}` bindings against a real `DataModel`; `genUiActionHandler`
  dispatches a `UserActionEvent` with the right name and sourceComponentId.

Every test must actually run green with `flutter test` / `dart test`.

## Example app

`example/lib/widgets/`: `product_card.dart`, `stat_tile.dart` (enum variant,
double), `tag_row.dart` (`List<String>`), `panel.dart` (`Widget` child +
`List<Widget>` children + `VoidCallback`). `example/lib/main.dart` builds a
`Catalog` from the four generated items plus `BasicCatalogItems.asCatalog()`
and renders the generated examples via genui's `DebugCatalogView` development
utility (no LLM/network required) so the app is runnable offline. A smoke
test in `example/test/` checks the catalog contents and that the page renders.

## Quality bar

- `dart analyze` clean on all packages (use `package:flutter_lints`).
- `dart format` clean.
- `pana`-friendly pubspecs: description, repository, issue_tracker, topics.
- README per package + root README with a 60-second quickstart and the
  "can't drift" argument up front.
- CHANGELOG.md starting at 0.1.0.
- MIT license, copyright Diego Alejandro López Camacho.
- No tool attribution anywhere in the repo.
