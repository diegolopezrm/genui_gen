# genui_gen

Annotate a Flutter widget, run `build_runner`, get a genui `CatalogItem` whose
schema, builder and examples are derived from the widget's constructor.

A page that shows it end to end — constructor to schema to the message an agent
sends, a recorded session you can step through, and what the tooling found in
the stock catalog: <https://diegolopezrm.github.io/genui_gen/>

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
  genui_gen: ^0.8.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.7.0
```

The generated code is a `part` of your file and builds its schema with
`S.object(...)`, so it needs that name in scope. `genui_gen` re-exports `S`,
`Schema` and `ObjectSchema` from `json_schema_builder` for exactly that, which
is why the package is not a direct dependency of yours. If `S` collides with
another one-letter name in a file — a generated localization class, say —
import `genui_gen` there with `hide S`.

### 2. Annotate a widget

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
part shares your imports, so the annotated file must import `genui` and
`genui_gen`, which re-exports the schema names the part needs.

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

Naming each item is fine for one widget. Once there are several, use the
generated `genui_catalog.g.dart` instead and let the list maintain itself —
see [Registering every item at once](#registering-every-item-at-once).

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
| `enum E`, `E?` | string reference with `enumValues` set to the enum's `name`s | `E.values.asNameMap()[value]`, falling back to the first constant when the property is required |
| `List<String>`, `List<String>?` | string array reference | `List<String>` |
| `List<int>`, `List<double>`, `List<num>` and nullable variants | `A2uiSchemas.listOrReference(items: S.number())` | entries converted with `toInt()` / `toDouble()` as needed |
| `List<E>`, `List<E>?` where `E` is an enum | `listOrReference` whose items carry the enum's `name`s | one `E` per entry; a name the enum does not declare is dropped |
| a class annotated with `@GenUiData`, and its nullable variant | a `oneOf` of the inlined object schema, a data binding and a function call | the decoded instance |
| `List<T>`, `List<T>?` where `T` is `@GenUiData` | `A2uiSchemas.listOrReference(items: <that object schema>)` | one decoded `T` per element |
| `Widget`, `Widget?` | component reference | `ctx.buildChild(id)` |
| `List<Widget>`, `List<Widget>?` | list of component references | one `ctx.buildChild` per id |
| `VoidCallback`, `void Function()` and nullable variants | action | a callback that dispatches a `UserActionEvent` |
| `void Function(T)` marked `@GenUiWrites`, where `T` is a `String`, a number, a `bool` or an enum | nothing; the callback is not a property | a callback that writes the user's value into the data model |
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

```dart
@GenUiWrites('value')           // the property this callback writes back to
```

`@GenUiWrites` is only valid on a callback that takes the new value, such as
`ValueChanged<bool>` or `void Function(String)`. See the next section.

## Registering every item at once

A catalog built by naming each item is a hand-maintained import list plus a
hand-maintained list of variable names. Add a `@GenUiWidget` and the catalog
stays as it was, silently — the same drift this package removes between a
widget and its schema, one level up.

The builder emits `lib/genui_catalog.g.dart` alongside the part files, holding
every generated item in the package:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:genui/genui.dart';

import 'widgets/product_card.dart';
import 'widgets/stat_tile.dart';

final List<CatalogItem> genUiCatalogItems = <CatalogItem>[
  productCardCatalogItem,
  statTileCatalogItem,
];

final Catalog genUiCatalog = Catalog(
  genUiCatalogItems,
  catalogId: 'com.example.app',
);
```

Which makes registering them one line, whatever the app grows into:

```dart
import 'genui_catalog.g.dart';

final catalog = genUiCatalog.copyWith(
  newItems: BasicCatalogItems.asCatalog().items.toList(),
);
```

The id comes from `build.yaml`, because it identifies the catalog to everything
outside the build — the agent that composes against it, the client that renders
it — which is not something a generator can invent:

```yaml
targets:
  $default:
    builders:
      genui_gen_builder:genui_catalog:
        options:
          catalog_id: com.example.app
```

Worth knowing:

- The list is sorted by variable name, so the file does not reorder itself
  between builds and a diff only shows what actually changed.
- A package with nothing annotated gets no file, rather than an empty one that
  looks like a mistake.
- Only this package's items are collected. Items from a package you depend on
  are that package's to export.
- Two libraries whose items would arrive under the same name are a build error
  naming both files. Inside one library the generator already caught that; the
  two only meet here, where the aggregate names each unprefixed.
- `@GenUiWidget(name: '...')` on a private class generates a private variable,
  which no other library can name. It is left out with a warning saying so,
  rather than emitting a file that does not compile.
- Without `catalog_id`, `genUiCatalog` is still assembled, just without an id.
  A surface names the catalog it was built against, so set one before talking
  to an agent.

## Handing the catalog to an agent (`catalog.json`)

Inside the app, genui puts the catalog in the prompt for you. Everything
outside this Flutter process needs it as a document: an agent written in
Python, a second client rendering the same surfaces in SwiftUI, a review that
has to answer what the model was allowed to ask for last Tuesday.

`genUiCatalogJson` turns the assembled catalog into that document — the shape
[A2UI publishes for its own basic
catalog](https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json), with
`catalogId`, `components`, `functions` and the `$defs` a renderer resolves a
component against:

```dart
final json = genUiCatalogJsonString(genUiCatalog, title: 'Acme catalog');
```

Generate it from a test, so the file in the repository cannot fall behind the
widgets and a reviewer sees what a new `@GenUiWidget` exposed to the model:

```dart
void main() {
  test('catalog.json describes the generated catalog', () {
    final file = File('catalog.json');
    final json = '${genUiCatalogJsonString(genUiCatalog)}\n';

    if (autoUpdateGoldenFiles) file.writeAsStringSync(json);

    expect(file.readAsStringSync(), json);
  });
}
```

```sh
flutter test test/catalog_json_test.dart --update-goldens
```

`example/catalog.json` is generated exactly that way. Worth knowing:

- The catalog needs an id. Without one the surface has no way to name it, so
  the export throws rather than writing a document nothing can reference.
- The `$ref`s point at the shared A2UI types for v0.9, the protocol version
  genui emits, so whatever resolves them needs network access or a local copy
  of `common_types.json`.
- `title` and `description` are worth passing. genui fills in `A2UI Catalog`
  and `Custom catalog of A2UI components and functions.` for every catalog ever
  generated, and an agent handed three of them has nothing else to tell them
  apart by.

## What the component exposes (`package:genui_gen/testing.dart`)

The schema half of a catalog is checked when it is generated. The other half —
what the rendered component says to the person using it — has nothing checking
it, and it is the half a Dart diff does not show. Adding a widget changes what
the model can make your app announce, press or report, and nobody sees that in
review.

`testing.dart` records it:

```dart
// test/genui_semantics_test.dart
testWidgets('the catalog exposes what it exposed before', (tester) async {
  final recorded = <String, List<GenUiSemanticNode>>{};

  for (final item in genUiCatalog.items) {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenUiExampleSurface(catalog: genUiCatalog, item: item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    recorded[item.name] = genUiRenderedSemantics();
    handle.dispose();
  }

  expect(
    genUiSemanticsGolden(recorded, File('test/genui_semantics.json')),
    isNull,
  );
});
```

```sh
GENUI_UPDATE_GOLDENS=1 flutter test test/genui_semantics_test.dart
```

The file it writes reads like this, and is meant to be reviewed:

```json
{
  "components": {
    "PreferenceRow": [
      {
        "role": "switch",
        "name": "Sample label",
        "state": {"on": true, "disabled": false},
        "actions": ["tap", "focus"]
      }
    ]
  }
}
```

Worth knowing:

- `GenUiExampleSurface` renders the item's generated example through a real
  `SurfaceController`, so the recording covers the whole path — schema,
  bindings, actions — rather than the widget called directly.
- A component that renders nothing a user can reach records an empty list. In
  the example app that is what `Icon` and `Image` do: genui builds them without
  a semantic label, so a screen reader is told nothing at all.
- The shape — role, name, value, state, actions, in traversal order — is the
  one [A2UI's rendering cases](https://github.com/a2ui-project/a2ui/issues/2738)
  are written in, because it is the only description of a rendered surface that
  Flutter, SwiftUI, Compose and the web can all be held to. The same recording
  therefore says what another renderer of your catalog would have to reproduce.
- Recording is not the default. A file that rewrites itself on every run cannot
  fail, and the point is to fail.

## When the screen was not in your source (`package:genui_gen/tracing.dart`)

Someone reports that the confirm button did nothing. You open the code and
there is no confirm button: a model composed that screen, once, from a context
that will not come back. There is nothing to open and nothing to inspect.

A trace is that session, kept:

```dart
final recorder = GenUiTraceRecorder.attach(
  controller,
  catalogId: genUiCatalog.catalogId,
  redact: const ['/user/email'],
);

transport.messages.listen(recorder.handleMessage);
...
await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
```

It keeps every message the agent sent, the contents of each surface's data
model whenever they changed — including the writes a user made that never went
back to the agent — and every action the app reported. Replay needs no model
and no network, because A2UI describes interfaces as data:

```dart
final player = GenUiTracePlayer(trace, catalog: genUiCatalog)..seek(7);

await tester.pumpWidget(MaterialApp(home: GenUiTraceView(player: player)));
expect(find.text('Confirm'), findsOneWidget);
```

Worth knowing:

- The replay renders against the catalog you hand it, which is usually the
  current one. That is how a session from last week becomes a regression test:
  a catalog change that breaks a real conversation fails here first.
- `redact` names the data model paths that must not reach the file. A
  recording keeps what the user typed, so the field holding an email belongs
  in that list before the first recording, not after the first leak.
- A component that reads a clock, a random number or a request renders from
  that rather than from the trace, and replays differently. Keep those behind
  a function the catalog declares and the trace covers them too.

## What a change costs the agent (`genUiCatalogDiff`)

A catalog is a contract with something that cannot be recompiled. Renaming a
property does not break your app; it breaks the agent, whose prompt still
describes yesterday's components, and it breaks quietly, one malformed message
at a time.

```dart
final changes = genUiCatalogDiff(published, genUiCatalogJson(genUiCatalog));

expect(changes.where((change) => change.isBreaking), isEmpty,
    reason: changes.join('\n'));
```

Breaking: a component or property that disappears, a property that becomes
required, a type that changes, an enum value that is gone. Not breaking, and
still reported: a new optional property, a new enum value, a reworded
description — which is not nothing, because the description is the
instruction.

## What the catalog gives a screen reader, and what it costs to send

```dart
final findings = genUiSemanticsAudit(recorded, allowEmpty: {'Divider'});
expect(findings, isEmpty, reason: findings.join('\n'));
```

Run over the recording the golden test already keeps, so accessibility is
checked by a file that exists rather than by a pass nobody remembers to run.
It reports a control with nothing to announce, a component that reaches
assistive technology as nothing at all, and two controls that announce
themselves identically.

`genUiCatalogWeight` answers the other question nothing makes visible: a
catalog travels in every request, and this says how much of the prompt each
component takes.

```
   14832 characters in total
     3401  22.9%  MetricsTable
     2180  14.7%  ProductCard
     ...
```

## Controls the user operates (`@GenUiWrites`)

A property on its own is read-only: the model puts a value there and the widget
displays it. A control the user operates has to report the new value back, and
genui's own basic catalog does that by writing it into the surface's data
model — that is what `TextField`, `Slider`, `CheckBox`, `ChoicePicker`,
`DateTimeInput` and `Tabs` all do.

`@GenUiWrites` gives an annotated widget the same ability:

```dart
@GenUiWidget(
  description:
      'One preference the user can turn on or off. Bind `enabled` to a data '
      'path and the switch writes the new state there.',
)
class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.label,
    required this.enabled,
    @GenUiWrites('enabled') this.onChanged,
  });

  /// A short caption naming the preference.
  final String label;

  /// Whether the preference is currently on.
  final bool enabled;

  /// Called with the new state when the user flips the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: enabled,
    onChanged: onChanged,
    title: Text(label),
  );
}
```

The model sends a binding, and reads the answer back from the path it chose:

```json
{
  "id": "notify",
  "component": "PreferenceRow",
  "label": "Weekly summary",
  "enabled": {"path": "/settings/notify"}
}
```

### What the generator does with it

- The callback is **not** a schema property. The model never supplies it, so it
  is left out of `properties` and out of `required`.
- The description of the property it writes to gains a sentence saying the
  component writes back to it, so the model knows that binding it to a path is
  how the answer is read.
- The property is read back through the same path it is written to, so the
  control reflects what the user just did.
- A literal still works. When the model sends `"enabled": true` rather than a
  binding, there is no path it named, so the value is written to
  `<componentId>.enabled` — the fallback genui's own `TextField` uses — and the
  literal is what the control starts from until that path holds something. The
  widget stays interactive either way.
- A write the data model refuses (an index out of bounds, a non-numeric segment
  on a list) is reported through `ctx.reportError` rather than thrown out of a
  gesture handler, the same way a failed action is.

### Rules

- The named property has to exist on the same widget, and it is the *wire*
  name: the one from `@GenUiProp(name: ...)` when the property was renamed.
- The callback's argument has to match the property's type. The numeric kinds
  are interchangeable (`int`, `double`, `num`), because the generated reader
  already coerces; an enum has to be the same enum.
- Only a `String`, a number, a `bool` or an enum can be written back. A list or
  an object would have to be written wholesale, and the property may have
  arrived as a `{"call": ...}` with no path behind it.
- The argument may not be nullable. A2UI has no agreed meaning for writing
  `null` to a path — some implementations clear it, others store null — so
  `ValueChanged<String?>` is a build error rather than a silent choice.
- Two callbacks may write the same property, which is what a slider with both
  `onChanged` and `onChangeEnd` needs.
- Every one of these is a build error that names both sides.

## Lists the data model fills (`@GenUiProp(template: true)`)

A list of children is usually written out by the agent, one id at a time.
That works until the list is the data: five tasks today, nine tomorrow, and
the agent composing a new surface every time one is added.

A2UI has the other shape, and a template property accepts it:

```dart
@GenUiWidget(description: 'A titled list of rows, one per item in the data.')
class TaskList extends StatelessWidget {
  const TaskList({
    super.key,
    required this.title,
    @GenUiProp(template: true) required this.rows,
  });

  final String title;

  /// One row per task.
  final List<Widget> rows;
```

The agent then sends the row once:

```json
{
  "id": "root", "component": "TaskList", "title": "Today",
  "rows": {"componentId": "task_row", "path": "/tasks"}
}
```

and one row is built per entry at `/tasks`. A new entry in the data model adds
a row without the agent being asked for anything.

Each child reads its own entry: the child of `/tasks` at index 2 binds `label`
against `/tasks/2/label`, so a single component describes every row. Children
are keyed by entry rather than by position, so a row removed from the middle
takes its state with it instead of handing it to the row that moved up.

Worth knowing:

- The property still accepts a plain list of ids, so an agent that writes the
  children out one by one keeps working.
- It is off by default. The schema a template property publishes is not the one
  a prompt tuned against the previous version was written for, so turning it on
  is your call, not the generator's.
- `template: true` on anything but a `List<Widget>` is a build error naming the
  parameter: a template repeats a component over a path, which means nothing
  for a string or a number.

## Structured data (`@GenUiData`)

Scalars only get you so far. A table, a chart series or a list of items needs
objects, and faking them with parallel arrays (`labels`, `values`, `trends`)
invites the model to emit three arrays of different lengths. `@GenUiData` marks
a plain Dart class as a shape the model may emit, so a widget parameter can be
that class or a `List` of it.

`lib/models/metric_row.dart`:

```dart
import 'package:genui_gen/genui_gen.dart';

import 'trend.dart';    // enum Trend { up, down, flat }

part 'metric_row.genui.dart';

@GenUiData(description: 'One row of a metrics table.')
class MetricRow {
  const MetricRow({
    required this.label,
    required this.value,
    required this.trend,
    this.note,
  });

  /// A short caption naming the metric.
  final String label;

  /// The current numeric value of the metric.
  final double value;

  /// Whether the metric went up, down or stayed flat.
  final Trend trend;

  /// An optional one-line comment about this row.
  final String? note;
}
```

A data class is not a widget, so its generated part holds a schema and a
decoder instead of a `CatalogItem`:

```dart
/// Generated schema for [MetricRow].
final ObjectSchema metricRowGenUiSchema = ObjectSchema(
  description: 'One row of a metrics table.',
  properties: {
    'label': S.string(description: 'A short caption naming the metric.'),
    'value': S.number(description: 'The current numeric value of the metric.'),
    'trend': S.string(
      description: 'Whether the metric went up, down or stayed flat.',
      enumValues: ['up', 'down', 'flat'],
    ),
    'note': S.string(description: 'An optional one-line comment about this row.'),
  },
  required: ['label', 'value', 'trend'],
);

/// Decodes a [MetricRow] from the map the model produced.
MetricRow metricRowFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => MetricRow(...);
```

`ObjectSchema(...)` and not `S.object(...)`: `Schema.object` is a redirecting
factory typed as `Schema`, so it cannot initialise an `ObjectSchema` variable.
Both build the same schema.

Now any annotated widget may take `MetricRow` or `List<MetricRow>`:

```dart
import '../models/metric_row.dart';

part 'metrics_table.genui.dart';

@GenUiWidget(
  description:
      'A titled table of metrics. Each row has a label, a numeric value, a '
      'trend and an optional note.',
)
class MetricsTable extends StatelessWidget {
  const MetricsTable({super.key, required this.title, required this.rows});

  /// The heading shown above the table.
  final String title;

  /// The rows of the table, in display order.
  final List<MetricRow> rows;

  @override
  Widget build(BuildContext context) => /* a DataTable */;
}
```

The row schema is inlined into the widget schema and the decoder is called per
element:

```dart
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'The heading shown above the table.',
      ),
      'rows': A2uiSchemas.listOrReference(
        description: 'The rows of the table, in display order.',
        items: metricRowGenUiSchema,
      ),
    },
    required: ['title', 'rows'],
```

```dart
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'rows': GenUiBinding.objectList(data['rows']),
      },
      builder: (context, v) => MetricsTable(
        title: v.string('title') ?? missing<String>('title', ''),
        rows:
            v
                .objectList('rows')
                ?.map((json) => metricRowFromGenUiJson(json, missingIn('rows')))
                .toList() ??
            missing<List<MetricRow>>('rows', const <MetricRow>[]),
      ),
```

so the model composes one component with real objects in it:

```json
{
  "id": "root",
  "component": "MetricsTable",
  "title": "Q3 performance",
  "rows": [
    {"label": "Revenue", "value": 128400, "trend": "up", "note": "vs. Q2"},
    {"label": "Churn", "value": 2.4, "trend": "down"}
  ]
}
```

### Rules for a data class

- Field types are the 0.1 scalar set (`String`, `int`, `double`, `num`, `bool`,
  enums, and a `List` of any of those) plus nested `@GenUiData` classes and
  lists of them.
  A `Widget` or a callback inside a data class is a build error naming the
  field: a data class is data the model emits, not a component reference.
- Inside the object the schema uses plain `S.string` / `S.integer` /
  `S.number`, not the `A2uiSchemas.*Reference` forms, because those values are
  literals. The binding applies to the whole property, so
  `"rows": {"path": "/report/rows"}` resolves through genui's `BoundList` while
  a `{"path": ...}` on an individual field inside a row does not — which is why
  the *property* schema is a union of the literal, a data binding and a
  function call, and the *field* schemas are not.
- No field is cast. Each one goes through the `genUiAs*` coercions the runtime
  exports, which apply genui's own `Bound*` rules, so a wrong-typed field
  degrades instead of throwing a `TypeError` inside `build`.
- Nested data schemas are inlined rather than `$ref`'d, so a data class that
  reaches itself (directly or transitively) is a build error naming the cycle.
- A required field the model omits falls back exactly as in 0.1 (`''`, `0`,
  `false`, the first enum value, `const []`) instead of throwing during build,
  and is reported to the model as `<property>.<field>` through
  `genUiReportMissing`. An optional field decodes to `null`, or to its Dart
  default, and is never reported. Nor is anything reported field by field when
  a `{"path": ...}` on the whole object has simply not resolved yet: that is
  one silent report of the property itself, not a burst of field errors.
- `@GenUiProp(description:, name:, ignore:)` applies to a data class
  constructor parameter the same way it applies to a widget parameter, and
  descriptions come from the same three places.
- A description on a property or field whose *type* is a data class is kept
  too, so one use site can say what the object means there without changing the
  shared class. On a widget property it becomes the description of the `oneOf`
  wrapper; on a field of another data class the inlined schema is copied with
  that description in place of the class's own.
- A generic data class, a field whose wire key would be the reserved `path` or
  `call`, and two data classes whose generated names collide at a use site are
  all build errors.

```dart
@GenUiData(
  description: 'Fed to the model as the object schema description.',
  constructor: 'fromRecord',    // named constructor to read; defaults to the unnamed one
)
```

A runnable version of all of this is in
[`example/lib/models/metric_row.dart`](example/lib/models/metric_row.dart) and
[`example/lib/widgets/metrics_table.dart`](example/lib/widgets/metrics_table.dart).

## Limitations (0.8)

Not supported yet; each produces a build error that names the parameter:

- Maps with arbitrary keys (`Map<String, Object?>`, `Map<String, double>`).
- Records.
- Callbacks with more than one argument, and one-argument callbacks whose value
  is not a `String`, a number, a `bool` or an enum. A single scalar argument is
  supported through [`@GenUiWrites`](#controls-the-user-operates-genuiwrites).
- Widgets or callbacks used as fields of a `@GenUiData` class, and data
  classes that reference themselves.

Two ways around it in the meantime:

- `@GenUiProp(ignore: true)` on the parameter, as long as it is optional or has
  a default. The model never sees it and the widget uses its default.
- Write a thin adapter widget whose constructor only takes supported types,
  have it build the real widget, and annotate the adapter. The adapter is the
  contract the model sees; the real widget stays untouched.

## Roadmap

- 0.2 (done): `@GenUiData` — a widget parameter may be an annotated data class
  or a `List` of one, with the object schema inlined and a generated decoder.
- 0.3 (done): lists of scalars — `List<int>`, `List<double>`, `List<num>` and
  `List<E>` for an enum `E`, as widget parameters and as `@GenUiData` fields.
- 0.4 (done): two-way binding — a `void Function(T)` marked `@GenUiWrites`
  writes the user's value into the surface's data model, so a switch, a slider
  or a text field can be annotated and the agent can read the answer back.
- 0.5 (done, `genui_gen_builder` only): an aggregating builder that emits a
  single `genui_catalog.g.dart` with every generated item in the package, so
  registering a catalog stops being a hand-maintained import list.
- 0.5: the aggregate assembles the `Catalog` itself, with the id from
  `build.yaml`, and `genUiCatalogJson` exports it as the A2UI `catalog.json`
  an agent or a non-Flutter client reads.
- 0.6: `package:genui_gen/testing.dart` — record what each generated component
  exposes to assistive technology and fail when it changes, in the shape A2UI's
  rendering cases use.
- 0.7: `package:genui_gen/tracing.dart` — record an agent session and replay it
  without a model, plus `genUiCatalogDiff`, `genUiSemanticsAudit` and
  `genUiCatalogWeight`: what a change costs the agent, what the catalog gives a
  screen reader, and what it costs to send.
- 0.8: `@GenUiProp(template: true)` — a list of children may be a template the
  data model repeats, so a list that grows does not need a new surface.
- Proposed next: accessibility — `ComponentCommon` declares `label` and
  `description` on every A2UI component and the conformance suite tests them.
  genui does not apply them yet
  ([a2ui#2697](https://github.com/a2ui-project/a2ui/issues/2697),
  [genui#1035](https://github.com/flutter/genui/pull/1035)); once it does, a
  generator is the one place to wire them in for every annotated widget.
- Proposed next: smarter example generation, where the author's own default
  values and the property description feed the sample instead of the fixed
  `42` / `Sample <name>` placeholders.

## Compatibility

- `genui ^0.10.0`
- Flutter `>=3.35.0`
- Dart `>=3.10.0 <4.0.0`
- `build_runner ^2.15.0`, `source_gen ^4.1.0`, `analyzer >=10.0.0 <15.0.0`

genui lives in [flutter/genui](https://github.com/flutter/genui) and is
pre-1.0; its `CatalogItem`, `A2uiSchemas` and binding APIs still move between
minor versions. This package tracks genui and bumps its constraint when genui
breaks. If you are on a newer genui than the constraint allows, open an issue.

## Packages

| Package | Put it in | What it holds |
|---|---|---|
| [`genui_gen`](packages/genui_gen) | `dependencies` | `@GenUiWidget`, `@GenUiData`, `@GenUiProp`, `@GenUiAction`, `@GenUiWrites` and the runtime helpers the generated code calls |
| [`genui_gen_builder`](packages/genui_gen_builder) | `dev_dependencies` | the `build_runner` generator, and the aggregating builder that emits `genui_catalog.g.dart` |
| [`example`](example) | - | six annotated widgets — one driven by a `@GenUiData` class, one a switch that writes back — rendered offline through genui's `DebugCatalogView` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

Diego Alejandro López Camacho
