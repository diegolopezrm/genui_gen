# genui_gen

[![pub package](https://img.shields.io/pub/v/genui_gen.svg?label=genui_gen&color=0175C2)](https://pub.dev/packages/genui_gen)
[![builder](https://img.shields.io/pub/v/genui_gen_builder.svg?label=genui_gen_builder&color=0175C2)](https://pub.dev/packages/genui_gen_builder)
[![pub points](https://img.shields.io/pub/points/genui_gen?label=pub%20points)](https://pub.dev/packages/genui_gen/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/diegolopezrm/genui_gen/blob/main/LICENSE)

Annotate a Flutter widget you already have. The
[genui](https://pub.dev/packages/genui) `CatalogItem` an agent composes
against — JSON schema, widget builder and few-shot example — is derived from
the widget's constructor, so it cannot drift from the widget it describes.

**[See it end to end, with a recorded agent session you can step through →](https://diegolopezrm.github.io/genui_gen/)**

## In one screen

You write this:

```dart
@GenUiWidget(description: 'A product card with price and image.')
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.title, required this.price, this.onTap});

  /// Product name.
  final String title;

  /// Price in USD.
  final double price;

  /// Fired when the card is tapped.
  final VoidCallback? onTap;
  // ...
}
```

`build_runner` derives the schema from the constructor — the property names
*are* the parameter names, the `required` list *is* the set of non-nullable
parameters without defaults, the descriptions come from the doc comments — and
writes the builder and the example too. The model may then send:

```json
{
  "id": "root",
  "component": "ProductCard",
  "title": "Noise-cancelling headphones",
  "price": { "path": "/cart/0/price" },
  "onTap": { "event": { "name": "onTap" } }
}
```

Every property takes a literal or a `{"path": ...}` binding, because the
generated builder composes genui's own `BoundString`, `BoundNumber`,
`BoundBool`, `BoundList` and `BoundObject`. Actions dispatch a
`UserActionEvent` exactly the way genui's core `Button` does.

Rename the parameter and the generated part changes in review, or the build
fails. There is no second source of truth to keep in sync.

## Install

```yaml
dependencies:
  genui: ^0.10.0
  genui_gen: ^0.9.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.8.0
```

This package is the runtime half of the pair: the annotations, and the helpers
the generated code calls. The generator itself lives in
[`genui_gen_builder`](https://pub.dev/packages/genui_gen_builder) and belongs in
`dev_dependencies`.

The generated code is a `part` of your file and builds its schema with
`S.object(...)`, so it needs that name in scope. `genui_gen` re-exports `S`,
`Schema` and `ObjectSchema` from `json_schema_builder` for exactly that, which
is why you do not depend on it directly. If `S` collides with another
one-letter name in a file — a generated localization class, say — import
`genui_gen` there with `hide S`.

## Annotate

`lib/widgets/product_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

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

```sh
dart run build_runner build
```

## Register the catalog

The builder also writes `lib/genui_catalog.g.dart`, holding every annotated
item in the package, sorted by name. Registering a catalog stays one line
whatever the app grows into:

```dart
import 'genui_catalog.g.dart';

final catalog = genUiCatalog.copyWith(
  newItems: BasicCatalogItems.asCatalog().items.toList(),
);

final controller = SurfaceController(catalogs: [catalog]);
```

The catalog's id comes from `build.yaml`, because it names your catalog to
everything outside the build — the agent that composes against it, the client
that renders it — which is not something a generator can invent:

```yaml
targets:
  $default:
    builders:
      genui_gen_builder:genui_catalog:
        options:
          catalog_id: com.example.app
```

Keep genui's basic catalog in the mix: the generated examples reference the
core `Text` component for child widgets.

## What a property can be

| Dart parameter type | Schema emitted | Passed to the constructor as |
|---|---|---|
| `String`, `String?` | `A2uiSchemas.stringReference` | the resolved `String` |
| `int`, `double`, `num` (+`?`) | `A2uiSchemas.numberReference` | converted with `toInt()` / `toDouble()` |
| `bool`, `bool?` | `A2uiSchemas.booleanReference` | the resolved `bool` |
| any `enum` (+`?`) | `A2uiSchemas.stringReference(enumValues: ...)` | `E.values.asNameMap()[value]` |
| `List<String>` (+`?`) | `A2uiSchemas.stringArrayReference` | `List<String>` |
| `List<int>`, `List<double>`, `List<num>` (+`?`) | `A2uiSchemas.listOrReference(items: S.number())` | entries converted per element |
| `List<E>` (+`?`) for an enum `E` | `listOrReference` carrying the enum's names | one `E` per entry; an unknown name is dropped |
| a `@GenUiData` class (+`?`) | `oneOf` of its object schema, a data binding and a function call | the decoded instance |
| `List<T>` (+`?`) where `T` is `@GenUiData` | `A2uiSchemas.listOrReference(items: <T schema>)` | one decoded `T` per entry |
| `Widget`, `Widget?` | `A2uiSchemas.componentReference` | `ctx.buildChild(id)` |
| `List<Widget>` (+`?`) | list of component references, or a template — see below | one `ctx.buildChild` per id or per entry |
| `VoidCallback`, `void Function()` (+`?`) | `A2uiSchemas.action` | a callback that dispatches a `UserActionEvent` |
| `void Function(T)` marked `@GenUiWrites` | nothing; it is not a property | a callback that writes the user's value into the data model |
| `Key? key`, `super.key` | skipped | not passed |
| anything else | build error naming the widget, parameter and type | — |

A required property that arrives missing or malformed does not throw during
build. The builder substitutes a fallback and reports the problem once per
component through `ctx.reportError`, as an `A2uiValidationException`, so the
model sees the widget and property names.

The full rules live in
[`genui_gen_builder`'s README](https://pub.dev/packages/genui_gen_builder).

## Controls the user operates

A plain property is read-only: the model puts a value there and the widget
displays it. A control has to report the new value back, which in A2UI means
writing it into the surface's data model — what genui's own `TextField`,
`Slider` and `CheckBox` do. `@GenUiWrites` gives an annotated widget the same
ability:

```dart
@GenUiWidget(description: 'One preference the user can turn on or off.')
class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.label,
    required this.enabled,
    @GenUiWrites('enabled') this.onChanged,
  });

  final String label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  // ...
}
```

The callback is not a schema property — the model never supplies it. The model
binds `enabled` to a path and reads the user's answer back from the same path.

## Lists the data model fills

A list of children is normally written out by the agent, one id at a time.
That works until the list *is* the data: five tasks today, nine tomorrow, and
a new surface composed every time one is added. Mark the property
`template: true` and it accepts the other shape A2UI allows:

```dart
@GenUiProp(template: true) required this.rows,   // List<Widget>
```

```json
{
  "id": "root", "component": "TaskList", "title": "Today",
  "rows": { "componentId": "task_row", "path": "/tasks" }
}
```

One row is built per entry at `/tasks`, each reading its own entry, keyed by
entry rather than by position. A new entry adds a row with nobody asked. It is
off by default, and the property still accepts a plain list of ids.

## Catalog functions

A catalog has two halves. Components are what the agent composes a surface out
of. Functions are what it computes a value with, through the `{"call": ...}`
form any bound property already accepts. genui ships fourteen (`required`,
`regex`, `email`, `formatString` and the rest), and adding one of your own
meant writing a `ClientFunction` by hand: the name, the description, an
argument schema spelled out in JSON schema, the return type, and an `execute`
that digs each argument back out of a map and casts it.

Annotate the function instead:

```dart
@GenUiFunction(description: 'Shortens a full name for display.')
String shortenName(
  /// The name to shorten.
  String name, {
  /// How to shorten it.
  NameStyle style = NameStyle.initials,
}) { ... }
```

The agent then names it, and never has to know the rule:

```json
{
  "id": "row", "component": "Text",
  "text": {
    "call": "shortenName",
    "args": { "name": {"path": "name"}, "style": "lastFirst" }
  }
}
```

The argument names are the parameter names, the required list is the set with
no default, the enum values come from the enum, and the return type comes from
the Dart return type. Arguments are coerced the way a widget property is, so a
model that sends a string where a number was declared degrades instead of
throwing inside the expression that called the function.

A `Future<T>` return becomes an async function and a `Stream<T>` a reactive
one, which is how a function with its own source of change (a clock, a
request, a path it watches) keeps answering.

The generated functions land in `genUiCatalogFunctions` and are handed to the
assembled `Catalog`, so adding one needs no other change, and they reach the
exported `catalog.json` under `functions` in the shape A2UI publishes for its
own.

## Structured data

Scalars only get you so far. Faking a table with parallel arrays (`labels`,
`values`, `trends`) invites the model to emit three arrays of different
lengths. `@GenUiData` marks a plain Dart class as a shape the model may emit,
so a widget property can be that class or a `List` of it:

```dart
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

The object schema is inlined into the widget schema and a decoder is generated
per class. A data class holds data, not components: its fields may be the
scalar types above, other `@GenUiData` classes, or lists of them. Widget and
callback fields are a build error, and so is a data class that reaches itself,
because schemas are inlined rather than referenced.

## Annotations

| Annotation | Target | Purpose |
|---|---|---|
| `@GenUiWidget(description:, name:, constructor:, isImplicitlyFlexible:)` | class | Marks a widget as a catalog component. `description` is required. |
| `@GenUiData(description:, constructor:)` | class | Marks a plain data class a widget property may take. |
| `@GenUiProp(description:, name:, ignore:, template:)` | parameter or field | Overrides the schema property; `ignore: true` excludes it, `template: true` lets a `List<Widget>` repeat over a data path. |
| `@GenUiAction(eventName:, description:)` | parameter or field | Customizes a `VoidCallback` action. |
| `@GenUiWrites('property')` | parameter or field | Makes a one-argument callback write the user's value back to that property's path. |
| `@GenUiFunction(description:, name:)` | top-level function | Declares a catalog function the model calls with `{"call": ...}`. |

Descriptions default to the parameter's doc comment, then the field's doc
comment.

## Three libraries

| Import | What it is for |
|---|---|
| `package:genui_gen/genui_gen.dart` | the annotations, the runtime helpers the generated code calls, and `genUiCatalogJson` |
| `package:genui_gen/testing.dart` | record what a component exposes to a screen reader and fail when it changes; audit the catalog; diff it against what you published; weigh what it costs the prompt |
| `package:genui_gen/tracing.dart` | record a real agent session and replay it with no model and no network |

### The catalog as a document

Inside the app genui puts the catalog in the prompt for you. Everything outside
this Flutter process needs it as a document: an agent written in Python, a
second client rendering the same surfaces in SwiftUI, a review that has to
answer what the model was allowed to ask for last Tuesday.

`genUiCatalogJson(catalog, {title, description})` returns the A2UI
`catalog.json` document — the shape A2UI publishes for its own basic catalog,
with `catalogId`, `components`, `functions` and the `$defs` a renderer resolves
a component against. It throws when the catalog has no `catalogId`, since a
surface names the catalog it was built against.

Generate it from a test, so the checked-in file cannot fall behind the widgets
and a reviewer sees what a new `@GenUiWidget` exposed to the model:

```dart
test('catalog.json describes the generated catalog', () {
  final file = File('catalog.json');
  final json = '${genUiCatalogJsonString(genUiCatalog)}\n';

  if (autoUpdateGoldenFiles) file.writeAsStringSync(json);

  expect(file.readAsStringSync(), json);
});
```

```sh
flutter test test/catalog_json_test.dart --update-goldens
```

### What the component exposes

The schema half of a catalog is checked when it is generated. The other half —
what the rendered component says to the person using it — has nothing checking
it, and it is the half a Dart diff does not show.

```dart
recorded[item.name] = genUiRenderedSemantics();
// ...
expect(genUiSemanticsGolden(recorded, File('test/genui_semantics.json')), isNull);
```

`GenUiExampleSurface` renders an item's generated example through a real
`SurfaceController`, so the recording covers schema, bindings and actions
together. Re-record a deliberate change with `GENUI_UPDATE_GOLDENS=1`. Role,
name, value, state and actions in traversal order is the shape A2UI's rendering
cases use, so the same file also says what a renderer of your catalog on
another platform would have to reproduce.

### Recording a session

Someone reports that the confirm button did nothing. You open the code and
there is no confirm button: a model composed that screen, once, from a context
that will not come back.

```dart
final recorder = GenUiTraceRecorder.attach(
  controller,
  catalogId: genUiCatalog.catalogId,
  redact: const ['/user/email'],
);
// ...
await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
```

The trace keeps every message the agent sent, the data model each time it
changed — including writes the user made that never went back to the agent —
and every action the app reported. `GenUiTracePlayer` and `GenUiTraceView` put
it back on screen at any step, with no model and no network, because A2UI
describes interfaces as data. That is how last week's session becomes this
week's regression test. `redact` names the paths a recording must not keep.

### Checking the contract and the cost

`genUiCatalogDiff` reports what changed for the model between two catalogs,
and which of those changes break a message the agent still knows how to write.
`genUiSemanticsAudit` reads the semantics recording and reports a control with
nothing to announce, a component that reaches assistive technology as nothing
at all, and two controls that announce themselves identically.
`genUiCatalogWeight` says how much of every prompt each component takes up.

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
- `genUiValueWriter` backs `@GenUiWrites`: it writes the user's value to the
  path the model bound the property to, or to `<componentId>.<property>` when
  the model sent a literal. A write the data model refuses is reported through
  `ctx.reportError` rather than thrown out of a gesture handler.
- `genUiTemplateChildren` and `genUiTemplatePath` back `template: true`: one
  child per entry at the path, each with that entry as its own data context,
  keyed by entry rather than by position.
- `genUiReportMissing(ctx, component, property)` reports a required property
  the model omitted as an `A2uiValidationException`, once per component
  instance. It stays silent for `{"path": ...}` and `{"call": ...}` bindings
  that have not resolved yet, because those rebuild on their own once the
  data model is populated.
- `genUiAsString`, `genUiAsNum`, `genUiAsBool`, `genUiAsStringList`,
  `genUiAsNumList`, `genUiAsObject` and `genUiAsObjectList` coerce one raw JSON
  value the way genui's `Bound*` widgets coerce a widget property. Generated
  decoders call them instead of casting, so a model that sends a number where a
  string was declared degrades exactly as it would for a widget property rather
  than throwing a `TypeError` inside `build`.
- `GenUiMissingFieldReporter`, `genUiMissingField` and `genUiNestedField` carry
  the same reporting down into a data object: the generated widget builder
  hands the decoder a reporter, so a required field the model left out of a row
  reaches the model as `rows.label` instead of being silently replaced.

## Compatibility

`genui ^0.10.0` · Flutter `>=3.35.0` · Dart `>=3.10.0 <4.0.0`

genui lives in [flutter/genui](https://github.com/flutter/genui) and is
pre-1.0; its `CatalogItem`, `A2uiSchemas` and binding APIs still move between
minor versions. This package tracks genui and bumps its constraint when genui
breaks.

## License

MIT. Copyright Diego Alejandro López Camacho.
