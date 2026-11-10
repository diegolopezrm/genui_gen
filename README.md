# genui_gen

Annotate a Flutter widget, run `build_runner`, get an
[a2ui_flutter](https://pub.dev/packages/a2ui_flutter) component whose schema,
builder and examples are derived from the widget's constructor.

A page that shows it end to end — constructor to schema to the message an agent
sends, a recorded session you can step through, and what the tooling found in
the stock catalog: <https://diegolopezrm.github.io/genui_gen/>

To see all of it in one app, [Quincena](https://github.com/diegolopezrm/quincena)
is personal finance where an agent composes every answer from twenty generated
components and six generated functions, with the inspector, recorded Gemini
sessions and the test helpers wired in. It runs in the browser with no key:
<https://diegolopezrm.github.io/quincena/> (it is still on genui_gen 0.14 and
genui).

Coming from genui? See [Migrating from genui](#migrating-from-genui).

## The problem

An a2ui_flutter catalog needs three things per widget: a JSON schema the model
composes against, a builder that turns the properties the renderer resolved
back into a widget, and examples that show the model what a message using the
widget looks like. Writing them by hand is tedious, and it drifts silently:
rename a constructor parameter, add a required one, change an enum, and the app
still compiles while the model keeps composing against an outdated contract.
And a schema alone does not teach a model to use a component: genui's README
said as much, and expected one-shot or few-shot examples for every one you add.
a2ui_flutter's `ComponentImplementation` has nowhere to keep them.

## Why derived beats hand-written

`genui_gen` reads the annotated constructor with the analyzer and emits the
component from it. The schema property names are the parameter names. The
required list is the set of non-nullable parameters without defaults. Enum
values are the enum's `name`s. The builder calls the constructor with every
property a2ui_core resolved against that schema, and the examples come from the
same constructor and reach the agent in the catalog's instructions. There is no
second source of truth to keep in sync: if the constructor changes and the
generated part is stale, the build fails or the regenerated file changes in
review. The catalog cannot drift from the widget because the catalog is a
function of the widget.

## 60-second quickstart

### 1. Add the dependencies

```yaml
dependencies:
  a2ui_core: ^0.6.0
  a2ui_flutter: ^0.2.0
  genui_gen: ^0.15.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.14.0
```

a2ui_flutter is the renderer, and it brings a2ui_core, the protocol core, with
it. `a2ui_core` is listed only because step 5 imports it for
`MessageProcessor`; a package that only declares components can leave it out.
a2ui_flutter needs Flutter 3.38 or later.

The generated code is a `part` of your file and names `GenUiComponent`,
`GenUiSchemas` and, for lists, maps and data classes, `S` from
`json_schema_builder`. `genui_gen` exports all of them, which is why the
annotated file needs one import and `json_schema_builder` is not a direct
dependency of yours. If `S` collides with another one-letter name in a file (a
generated localization class, say), import `genui_gen` there with `hide S`.

### 2. Annotate a widget

`lib/widgets/product_card.dart`:

```dart
import 'package:flutter/material.dart';
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
part shares your imports, so the annotated file must import `genui_gen`, which
exports every name the part needs.

### 3. Generate

```sh
dart run build_runner build
```

### 4. Register the component

```dart
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';

final catalog = basicCatalog().derive(
  catalogId: 'com.example.shop',
  addComponents: [productCardCatalogItem],
);
```

A v0.9 surface draws on one catalog, so the generated component joins the basic
catalog rather than standing beside it: the agent composes the card with a
basic `Row` or `Text`, and the generated examples use `Text` for child widgets.
`derive` keeps the basic components, their functions and the definitions they
refer to.

Naming each component is fine for one widget. Once there are several, use the
generated `genui_catalog.g.dart` instead and let the list maintain itself (see
[Registering every component at once](#registering-every-component-at-once)).

### 5. Render what the agent sends

```dart
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';

final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [catalog],
);

// What the user does on a surface, for the app to send to the agent.
processor.model.onAction.subscribe((action) => agent.send(action));

// Every message the agent sends.
processor.processMessages(jsonDecode(line));

// Once the agent has created the surface:
A2uiSurface(surface: processor.model.getSurface('main')!)
```

The agent creates the surface with a `createSurface` message naming the
catalog's id, here `com.example.shop`, then fills it with `updateComponents`
and `updateDataModel`. Every message carries its protocol version
(`"version": "v0.9"`), and the processor rejects one that does not.

### What gets generated

`product_card.genui.dart` (trimmed):

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'product_card.dart';

/// Generated [GenUiComponent] for [ProductCard].
final GenUiComponent productCardCatalogItem = GenUiComponent(
  name: 'ProductCard',
  schema: GenUiSchemas.component(
    description: 'A product card with price and image.',
    properties: {
      'title': GenUiSchemas.string(description: 'Product name.'),
      'price': GenUiSchemas.number(description: 'Price in USD.'),
      'imageUrl': GenUiSchemas.string(description: 'Optional image URL.'),
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
    "imageUrl": "https://picsum.photos/seed/genui_gen/400/225",
    "onTap": {
      "event": {
        "name": "onTap"
      }
    }
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

Every property accepts a literal, a data binding (`{"path": ...}`) or a
function call (`{"call": ...}`), because its schema is one of A2UI's dynamic
types (`DynamicString`, `DynamicNumber` and the rest). a2ui_core resolves it
against the surface's data model before the builder runs, and rebuilds the
widget when the value changes, so the builder only reads it. An action is the
closure a2ui_core resolved for it, the same kind the basic `Button` calls.

`GenUiSchemas.component` adds the two properties every basic component takes,
`accessibility` and `weight`, and closes the schema: a property the widget does
not take is rejected when the message arrives, so the agent cannot invent one.
a2ui_flutter applies the `accessibility` label and description to whatever the
widget builds.

The `?? ''` is not for a property the agent left out: a2ui_core rejects a
component missing a required property before anything is built. It covers a
property bound to a path that holds nothing yet, which renders empty until the
data arrives, the way a basic component shows an empty text.

## Supported parameter types

| Dart parameter type | Schema emitted | Passed to the constructor as |
|---|---|---|
| `String`, `String?` | `GenUiSchemas.string` (`DynamicString`) | `props.string(name)` |
| `int`, `double`, `num` and nullable variants | `GenUiSchemas.number` (`DynamicNumber`) | `props.number(name)`, with `toInt()` for an `int` |
| `bool`, `bool?` | `GenUiSchemas.boolean` (`DynamicBoolean`) | `props.boolean(name)` |
| `enum E`, `E?` | `GenUiSchemas.string(enumValues: ...)`: one of the enum's `name`s, a data binding or a function call | `E.values.asNameMap()[value]`, falling back to the first constant when the property is required |
| `List<String>`, `List<String>?` | `GenUiSchemas.stringList` (`DynamicStringList`) | `genUiAsStringList(props.value(name))` |
| `List<int>`, `List<double>`, `List<num>` and nullable variants | `GenUiSchemas.list(items: S.number())` | `genUiAsNumList(props.value(name))`, entries converted with `toInt()` / `toDouble()` as needed |
| `List<E>`, `List<E>?` where `E` is an enum | `GenUiSchemas.list(items: S.string(enumValues: ...))` | one `E` per entry; a name the enum does not declare is dropped |
| a class annotated with `@GenUiData`, and its nullable variant | `GenUiSchemas.object(literal: <its ObjectSchema>)`: the object, a data binding or a function call | the decoded instance |
| `List<T>`, `List<T>?` where `T` is `@GenUiData` | `GenUiSchemas.list(items: <that ObjectSchema>)` | one decoded `T` per element |
| `Map<String, V>`, `Map<String, V>?` where `V` is a scalar, an enum or `Object?` | `GenUiSchemas.object(literal: S.object(additionalProperties: ...))` | the coerced `Map`; an entry the model got wrong is dropped |
| `Widget`, `Widget?` | `GenUiSchemas.componentId` | `buildChild` of the node in `props.child(name)` |
| `List<Widget>`, `List<Widget>?` | `GenUiSchemas.componentIdList`, or `GenUiSchemas.childList` with `template: true` | `props.children(name).map(buildChild)` |
| `VoidCallback`, `void Function()` and nullable variants | `GenUiSchemas.action` | `props.action(name)`, the closure a2ui_core resolved |
| `void Function(T)` marked `@GenUiWrites`, where `T` is a `String`, a number, a `bool` or an enum | nothing; the callback is not a property | `genUiWriter<T>(context, props, property)`, which writes the user's value to the path the property is bound to |
| `Key? key` / `super.key` | skipped | not passed |
| anything else | build error naming the widget, parameter and type | see Limitations |

### Required, optional, defaults

- A property is listed in the schema's `required` array only when the
  parameter is `required`, has no default value and is non-nullable.
- A parameter with a default value is optional, and the generated builder falls
  back to that default when the model leaves the property out, so the Dart
  default applies.
- A required property the model leaves out or sends with the wrong type, and a
  property the widget does not take, are rejected when the message arrives:
  a2ui_core checks every component against its schema before anything is
  built, and raises an error the app sends back to the agent. The fallbacks the
  builder carries (`''`, `0`, `false`, the first enum value, `const []`,
  `SizedBox.shrink()`, a no-op callback) cover a property bound to a path that
  holds nothing yet, which rebuilds on its own when the data model is
  populated.
- A data object bound to a path was not checked against the schema, so a
  required field missing from it is reported to the agent; see
  [Structured data](#structured-data-genuidata).
- The generated examples use the basic `Text` component for child widgets, so
  compose your components with the basic catalog (as in step 4).

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
  isImplicitlyFlexible: false,  // genui only; see below
)
```

`isImplicitlyFlexible` has no effect on a2ui_flutter, where a basic `Row` or
`Column` sizes a child by the `weight` the agent gives it, a property every
generated component takes. The builder warns when it is set.

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
  eventName: 'addToCart',       // event name in the generated example; defaults to the parameter name
  description: 'Fired when the user adds the product to the cart.',
)
```

`@GenUiAction` is only valid on `VoidCallback` / `void Function()` parameters.
The event the app receives is whatever the agent put in the action; `eventName`
only seeds the example.

```dart
@GenUiWrites('value')           // the property this callback writes back to
```

`@GenUiWrites` is only valid on a callback that takes the new value, such as
`ValueChanged<bool>` or `void Function(String)`. See the next section.

## Registering every component at once

A catalog built by naming each component is a hand-maintained import list plus
a hand-maintained list of variable names. Add a `@GenUiWidget` and the catalog
stays as it was, silently — the same drift this package removes between a
widget and its schema, one level up.

The builder emits `lib/genui_catalog.g.dart` alongside the part files, holding
every generated component and function in the package:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:genui_gen/genui_gen.dart';

import 'widgets/product_card.dart';
import 'widgets/stat_tile.dart';

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

Which makes registering them one call, whatever the app grows into:

```dart
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';

import 'genui_catalog.g.dart';

final catalog = basicCatalog().derive(
  catalogId: genUiCatalog.id,
  addComponents: genUiCatalogItems,
  addFunctions: genUiCatalogFunctions,
  instructions: genUiCatalog.instructions,
);
```

`basicCatalog` comes from `package:a2ui_flutter/v0_9/basic_catalog.dart` for
protocol v0.9, or from `package:a2ui_flutter/basic_catalog.dart` for v1.0. The
generated components render on either; a catalog derived from the v1.0 one
takes v1.0 messages. Compose with `derive` rather than by hand:
`CatalogImplementation(components: [...BasicComponents.all, ...])` drops the
definitions the basic components refer to, and fails.

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

- The lists are sorted by variable name, so the file does not reorder itself
  between builds and a diff only shows what actually changed.
- A package with nothing annotated gets no file, rather than an empty one that
  looks like a mistake.
- Only this package's components and functions are collected. Those of a
  package you depend on are that package's to export.
- Two libraries whose components would arrive under the same name are a build
  error naming both files. Inside one library the generator already caught
  that; the two only meet here, where the aggregate names each unprefixed.
- `@GenUiWidget(name: '...')` on a private class generates a private variable,
  which no other library can name. It is left out with a warning saying so,
  rather than emitting a file that does not compile.
- Without `catalog_id` the file declares the two lists and no `genUiCatalog`:
  an a2ui_flutter catalog cannot exist without an id, and a surface names the
  catalog it was built against. The build warns and says where to set it.
- `genUiCatalog.instructions` shows the agent an example of each component,
  written by `genUiExampleInstructions`. `derive` does not carry a catalog's
  instructions over, which is why the snippet above passes them; the catalog
  document then takes them to any agent that reads it.

## Handing the catalog to an agent (`catalog.json`)

An agent learns what it may compose from the catalog. One running in this
process can read the `CatalogImplementation`; everything outside it needs a
document: an agent written in Python, a second client rendering the same
surfaces in SwiftUI, a review that has to answer what the model was allowed to
ask for last Tuesday.

`genUiCatalogJson` turns the assembled catalog into that document, in the shape
[A2UI publishes for its own basic
catalog](https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json):
`catalogId`, the `instructions` with an example of each component,
`components`, `functions` and the `$defs` a renderer resolves a component
against. It is a2ui_core's `validationSchema` for the catalog, with the title
and description you pass:

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

- The document stands on its own. Every shared A2UI type a component refers to
  (`DynamicString`, `Action`, `ChildList` and the rest) is copied under
  `$defs`, so resolving it needs nothing from the network.
- A component is closed with `unevaluatedProperties: false`, which is what
  rejects a property the widget does not take.
- `title` and `description` are worth passing. The document has neither
  otherwise, and an agent handed three catalogs has nothing else to tell them
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

  for (final GenUiComponent component in genUiCatalogItems) {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenUiExampleSurface(catalog: catalog, component: component),
        ),
      ),
    );
    await tester.pumpAndSettle();

    recorded[component.name] = genUiRenderedSemantics();
    handle.dispose();
  }

  expect(
    genUiSemanticsGolden(recorded, File('test/genui_semantics.json')),
    isNull,
  );
});
```

`catalog` is the one the app composes with the basic catalog: a surface draws
on one catalog, and an example with a child composes it from the basic `Text`.

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
        "state": {"on": false, "selected": false, "disabled": false},
        "actions": ["tap", "focus"]
      }
    ]
  }
}
```

Worth knowing:

- `GenUiExampleSurface` sends the component's generated example through a real
  `MessageProcessor` and renders it in an `A2uiSurface`, so the recording
  covers the whole path (schema, bindings, actions) rather than the widget
  called directly. The example goes out in the protocol version the catalog
  declares, v0.9 when it declares none.
- A component that renders nothing a user can reach records an empty list,
  which the audit below reports. Only components with examples are recorded
  this way: a2ui_flutter's basic components carry none, so the example app
  writes a few of them out by hand in `test/genui_audit_test.dart`.
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

A trace is that session, kept. Attach a recorder to the app's processor, and
send the agent's messages through the recorder rather than straight to the
processor:

```dart
final recorder = GenUiTraceRecorder.attach(
  processor,
  catalogId: catalog.id,
  redact: const ['/user/email'],
);

transport.messages.listen(recorder.processMessages);
...
await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
```

`recorder.processMessages` records each message and hands it to the processor.
The trace keeps every message the agent sent, the contents of each surface's
data model whenever they changed (including the writes a user made that never
went back to the agent), and every action or error the app sent back, as the
messages the agent received. Replay needs no model and no network, because
A2UI describes interfaces as data:

```dart
final player = GenUiTracePlayer(trace, catalog: catalog)..seek(7);

await tester.pumpWidget(MaterialApp(home: GenUiTraceView(player: player)));
expect(find.text('Confirm'), findsOneWidget);
```

Worth knowing:

- The replay renders against the catalog you hand it, which is usually the
  current one. That is how a session from last week becomes a regression test:
  a catalog change that breaks a real conversation fails here first. A message
  today's catalog rejects is kept in `player.rejections`, and the replay goes
  on.
- `redact` names the data model paths that must not reach the file. A
  recording keeps what the user typed, so the field holding an email belongs
  in that list before the first recording, not after the first leak.
- A component that reads a clock, a random number or a request renders from
  that rather than from the trace, and replays differently. Keep those behind
  a function the catalog declares and the trace covers them too.

## Rendering what the schema allows (`genUiFuzz`)

A catalog is a contract with something that cannot be recompiled, and the only
thing holding a model to it is a JSON schema. Every widget test you write
checks the input you had in mind. `genUiFuzz` checks the ones the schema
permits and you did not.

```dart
testWidgets('the catalog survives what its own schema allows', (tester) async {
  final findings = await genUiFuzz(
    catalog: catalog,
    pump: tester.pumpWidget,
  );
  expect(findings, isEmpty, reason: '${genUiFuzzSummary(findings)}\n\n'
      '${findings.take(10).join('\n\n')}');
});
```

It renders each generated component's own example with each property replaced
by something else that property could hold: a required one left out, a null, a
string where a number was declared, an empty list, a list of two hundred
entries, a binding that never resolves, a call to a function nobody
registered, a string longer than any layout expects. Every case goes through
the catalog's own validation first, as an agent's message would. A case the
schema rejects is the protocol doing its job and is skipped; what is reported
is a case the schema accepts and the widget cannot take.

Every finding carries the component the renderer was handed, so a case is
something to paste into a test rather than a description to reconstruct. This
one is from genui's basic `Slider`:

```
Slider: `max` as an empty list
  threw: type 'List<Object?>' is not a subtype of type 'num?' in type cast
  {"id":"root","component":"Slider","value":0.5,"max":[]}
```

The cases are built by mutating the examples rather than by reading the
schema, which means a hand-written `GenUiComponent` is fuzzed as well as a
generated one, as long as it carries an example. A component without one, such
as a basic a2ui_flutter component, is left out. The order is fixed, so a run is
reproducible and `maxCasesPerComponent` always drops the same tail.

Worth knowing:

- A component whose own example the catalog rejects is reported once, as
  `rejected`, and not fuzzed further: the example and the schema disagree, and
  nothing else about the component means much until they agree.
- `reportEmpty` also reports a case that rendered nothing at all. It is off by
  default because most of those are correct: take the items away from a list
  and it has nothing to draw. Turn it on to find the component that swallows a
  wrong-typed property and leaves a blank space where the agent asked for
  something.
- `skip` and `only` take component names. Naming the ones you have accepted,
  rather than leaving them out of the run, is what tells you the day they are
  fixed.
- `host` is the app each surface is drawn in, a plain `MaterialApp` unless you
  pass one. Components that read their app's theme, a `ThemeExtension` with
  your design tokens for instance, need that app to render at all, or every one
  fails the same way before any case runs:
  `host: (surface) => MaterialApp(theme: appTheme, home: Scaffold(body: SingleChildScrollView(child: surface)))`.
- Pointed at genui's basic catalog, back when genui_gen was built on genui, it
  reported 69 crashing cases across five components, filed as
  [a2ui#2872](https://github.com/a2ui-project/a2ui/issues/2872).

## What the agent actually used (`genUiCoverage`)

A catalog travels in every request whether the agent composes with it or not.
`genUiCatalogWeight` says what each component costs; this says which ones
earned it.

```dart
final coverage = genUiCoverage(catalog: catalog, traces: recorded);
print(coverage.describe());
```

Over the traces [`tracing.dart`](#when-the-screen-was-not-in-your-source-packagegenui_gentracingdart)
already records, for the example app:

```
9 of 26 components used across 5 sessions and 5 surfaces
  never composed:
       909  1.6%  AudioPlayer
       993  1.7%  Card
      1192  2.1%  CheckBox
       ...
     21740  37.8%  in every request, for components the agent never asked for
  composed, with properties never filled:
    Panel: meta, onClose
    StatTile: history
    TaskList: emptyLabel
  enum values never chosen:
    StatTile.trend: down, flat
```

That last number is the one worth looking at. It is not a rule to enforce: a
catalog is written before the conversations that use it, and an error state
should be rare. It is the answer, with data rather than intuition, to whether
the catalog is too big and which part of it is the dead weight.

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

It reads a property the same whichever renderer wrote the document, so a
`catalog.json` published while the app was on genui diffs cleanly against its
a2ui_flutter version. For the example app, that diff finds no breaking change.

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
component takes. For the example app's generated catalog:

```dart
print(genUiCatalogWeight(genUiCatalogJson(genUiCatalog)).describe());
```

```
22536 characters in total
     2006  8.9%  MetricsTable
     1979  8.8%  Panel
     1841  8.2%  StatTile
     ...
    10368  46.0%  (shared definitions)
```

## Controls the user operates (`@GenUiWrites`)

A property on its own is read-only: the model puts a value there and the widget
displays it. A control the user operates has to report the new value back, and
the basic catalog does that by writing it into the surface's data model, which
is what `TextField`, `Slider`, `CheckBox`, `ChoicePicker` and `DateTimeInput`
do.

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
- The builder passes `genUiWriter<bool>(context, props, 'enabled')`, which
  writes through the binding of the property. The property is read through the
  same binding, so the control shows what the user just did.
- A literal is read-only. When the model sends `"enabled": true` rather than a
  binding, there is no path to write to and `genUiWriter` returns `null`, the
  way a basic `CheckBox` with a literal value is read-only. A nullable callback
  receives that `null`, so the widget can show itself disabled; a non-nullable
  one receives a callback that does nothing.
- The generated example binds the property to a path named after it
  (`"enabled": {"path": "/enabled"}`). An agent copies the examples it is
  shown, and a literal there would teach it to send a control nobody can
  change.
- A write the data model refuses (an index out of bounds, a non-numeric segment
  on a list) is reported on the surface's `onError` with the data model's own
  error code, the way the basic controls report it, rather than thrown out of a
  gesture handler.

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

## Validation the agent writes (`@GenUiChecked`)

A2UI lets the agent attach rules to an input component. A `CheckRule` is a
condition to evaluate and the message to show when it fails, and both are
required. The rules belong to the agent rather than to you, because what counts
as valid depends on what it is asking for; a widget only has to be willing to
say so.

```dart
@GenUiWidget(description: 'A labelled text input.')
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    @GenUiWrites('value') this.onChanged,
    @GenUiChecked() this.error,
  });

  final String label;
  final String value;
  final ValueChanged<String>? onChanged;

  /// The message of the first failing rule, or null while all of them pass.
  final String? error;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, errorText: error),
  );
}
```

The annotation does two things: it adds a `checks` property to the generated
schema, so the model may send rules at all, and it hands that parameter the
answer instead of taking it from the model. a2ui_core evaluates the rules
against the data model, and the builder reads the result. The agent then sends:

```json
{
  "id": "email", "component": "LabeledField", "label": "Email",
  "value": {"path": "/form/email"},
  "checks": [
    {
      "condition": {
        "call": "required",
        "args": { "value": {"path": "/form/email"} }
      },
      "message": "We need an email to reach you."
    }
  ]
}
```

Together with `@GenUiWrites` that closes the loop without the agent in it: the
user types, the value lands at `/form/email`, the rule is re-evaluated against
that same path, and the message clears. No message goes back over the wire.

### What the parameter may be

| Dart type | Receives |
|---|---|
| `String?` | the message of the first failing rule, `null` while all pass |
| `bool`, `bool?` | whether every rule passes |
| `GenUiCheckResult` | both |

A non-nullable `String` is a build error: a passing rule has no message to give
it.

Worth knowing:

- **Each rule keeps its message.** a2ui_core evaluates the rules one at a time
  and hands the builder `isValid` and the messages of the ones that fail, in
  the order the agent listed them, and a `String?` parameter gets the first.
  The message is the only part of a rule a person ever reads, and the agent
  wrote it for them.
- A rule fails while its condition is anything but `true`, including a
  condition whose binding holds nothing yet. A `required` rule on a field the
  user has not filled shows its message from the start.
- A condition usually calls one of the basic catalog's functions (`required`,
  `regex`, `length`, `numeric`, `email`), so those functions have to be in the
  catalog the processor holds. `derive` keeps them and `addFunctions` puts
  yours next to them; a catalog put together another way can leave the rules
  naming functions nobody registered.

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
against `/tasks/2/label`, so a single component describes every row. a2ui_core
expands the template, and keys each child by its path (`/tasks/2`), so a row's
widget state belongs to its position in the list rather than to its entry.

Worth knowing:

- The property still accepts a plain list of ids, so an agent that writes the
  children out one by one keeps working.
- It is off by default. A template property publishes A2UI's `ChildList`,
  where a plain one takes only ids, and that is not the schema a prompt tuned
  against the previous version was written for, so turning it on is your call,
  not the generator's.
- `template: true` on anything but a `List<Widget>` is a build error naming the
  parameter: a template repeats a component over a path, which means nothing
  for a string or a number.

## Catalog functions (`@GenUiFunction`)

A catalog has two halves, and everything above is one of them. Components are
what the agent composes a surface out of. Functions are what it computes a
value with, through the `{"call": ...}` form every dynamic property already
accepts. The basic catalog registers fourteen of them (`required`, `regex`,
`length`, `numeric`, `email`, `openUrl`, `formatString`, `formatNumber`,
`formatCurrency`, `formatDate`, `pluralize`, `and`, `or`, `not`), and adding
one of your own meant writing a `FunctionImplementation` by hand:

```dart
class ShortenName extends FunctionImplementation {
  ShortenName()
    : super(
        name: 'shortenName',
        description: '...',
        argumentSchema: S.object(       // written beside the code that
          properties: {                 // reads it back, and free to
            'name': ...,                // drift from it
          },
          required: ['name'],
        ),
        returnType: A2uiReturnType.string,
      );

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => _shorten(args['name'] as String);  // and a cast
}
```

Annotate the function instead:

```dart
enum NameStyle { initials, firstOnly, lastFirst }

@GenUiFunction(description: 'Shortens a full name for display.')
String shortenName(
  /// The name to shorten.
  String name, {
  /// How to shorten it.
  NameStyle style = NameStyle.initials,
}) { ... }
```

The agent names the function and never learns the rule:

```json
{
  "id": "row",
  "component": "Text",
  "text": {
    "call": "shortenName",
    "args": { "name": {"path": "name"}, "style": "lastFirst" }
  }
}
```

Put that inside a [template](#lists-the-data-model-fills-genuiproptemplate-true)
and one component describes every row of a list whose text the app computes:
three people in the data model, three rows reading `Lovelace, Ada`,
`Hopper, Grace`, `Turing, Alan`, with neither the strings nor the rule ever on
the wire.

### What comes from the signature

| Part of the function | Becomes |
|---|---|
| parameter names | the argument schema's property names |
| parameters with no default, non-nullable | the `required` list |
| parameter doc comments, or `@GenUiProp(description:)` | the argument descriptions |
| an enum parameter | a string argument carrying the enum's `name`s |
| the Dart return type | `A2uiReturnType` |
| `Future<T>` | an async function (`GenUiClientFunction.async`) |
| `Stream<T>` | a reactive one (`.streaming`), for a clock, a request, a watched path |

a2ui_core resolves every argument before it calls the function, and the
generated body reads each one through the same coercions a `@GenUiData` field
uses, so a value of the wrong type, which a binding can bring in from the data
model, degrades rather than throwing inside the expression that called the
function. A required argument the model omits falls back the same way,
silently, because a function has no component to attribute the error to. An
async or streaming function keeps one answer per set of arguments, so
a2ui_core evaluating it again does not start the call over.

Arguments may be a `String`, a number, a `bool`, an enum, a `List` of those, or
a `@GenUiData` class and a `List` of one. The object schema is inlined and the
generated decoder is called per argument, exactly as it is for a widget
property. A `Widget` or a callback is a build error naming the parameter: a
function receives values the expression system already resolved, and has no
surface to build a child on or event to dispatch.

Worth knowing:

- The generated functions land in `genUiCatalogFunctions` and in the generated
  `genUiCatalog`, and `derive(addFunctions: ...)` puts them next to the basic
  ones, so adding one needs no other change anywhere. They reach the exported
  `catalog.json` under `functions`, in the shape A2UI publishes for its own
  basic catalog.
- A name the basic catalog already registers is a build error. A catalog is a
  map from name to function, so a second `required` would replace the one that
  is there and change what every prompt written against it means. Rename it
  with `@GenUiFunction(name: ...)`.
- A private function is a build error too: the generated variable would be
  private, and no other library could put it in a catalog.

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
decoder instead of a component:

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
      'title': GenUiSchemas.string(
        description: 'The heading shown above the table.',
      ),
      'rows': GenUiSchemas.list(
        description: 'The rows of the table, in display order.',
        items: metricRowGenUiSchema,
      ),
    },
    required: ['title', 'rows'],
```

```dart
  builder: (context, node, props, buildChild) => MetricsTable(
    title: props.string('title') ?? '',
    rows:
        genUiAsObjectList(props.value('rows'))
            ?.map(
              (json) => metricRowFromGenUiJson(
                json,
                genUiMissingIn(context, node, 'rows'),
              ),
            )
            .toList() ??
        const <MetricRow>[],
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
  `S.number`, not the dynamic `GenUiSchemas` forms, because those values are
  literals. The binding applies to the whole property: a2ui_core resolves
  `"rows": {"path": "/report/rows"}` to the list at that path, and a
  `{"path": ...}` on a field inside a row is only an object. That is why the
  *property* schema is a union of the literal, a data binding and a function
  call, and the *field* schemas are not.
- No field is cast. Each one goes through the `genUiAs*` coercions the runtime
  exports (a numeric string reads as a number, `"true"` and `"false"` as
  booleans), so a wrong-typed field degrades instead of throwing a `TypeError`
  inside `build`.
- Nested data schemas are inlined rather than `$ref`'d, so a data class that
  reaches itself (directly or transitively) is a build error naming the cycle.
- A literal object was checked against the schema when its message arrived, so
  it cannot be missing a required field. One bound to a path was not: a
  required field missing there falls back exactly as in 0.1 (`''`, `0`,
  `false`, the first enum value, `const []`) instead of throwing during build,
  and `genUiMissingIn` reports it to the agent, once per component, on the
  surface's `onError`, as a `VALIDATION_FAILED` error at `/<property>/<field>`
  (`/rows/label`). An optional field decodes to `null`, or to its Dart default,
  and is never reported. Nothing is reported while the path holds nothing yet:
  the property falls back to empty and no row is decoded.
- `@GenUiProp(description:, name:, ignore:)` applies to a data class
  constructor parameter the same way it applies to a widget parameter, and
  descriptions come from the same three places.
- A description on a property or field whose *type* is a data class is kept
  too, so one use site can say what the object means there without changing the
  shared class. On a widget property it becomes the description of the union
  around the object; on a field of another data class the inlined schema is
  copied with that description in place of the class's own.
- A generic data class, a field whose wire key would be the reserved `path` or
  `call`, and two data classes whose generated names collide at a use site are
  all build errors. So is a field with the wire key `event` or `functionCall`
  on a class a property takes directly, which a2ui_core would read as an
  action, and a pair of fields `condition` and `message` on a class a property
  takes a list of, which it would read as checks. A class nested inside another
  keeps any name.

```dart
@GenUiData(
  description: 'Fed to the model as the object schema description.',
  constructor: 'fromRecord',    // named constructor to read; defaults to the unnamed one
)
```

A runnable version of all of this is in
[`example/lib/models/metric_row.dart`](example/lib/models/metric_row.dart) and
[`example/lib/widgets/metrics_table.dart`](example/lib/widgets/metrics_table.dart).

## Limitations (0.15)

Not supported yet; each produces a build error that names the parameter:

- Maps with a key that is not a `String`, or with a nullable value. A JSON
  object has no other kind of key, and a schema cannot say that one value is
  absent and another is null.
- Records. The shape would translate, but a record has nowhere to put a doc
  comment on its fields, and that per-field description is most of what makes
  a catalog entry usable, since it is what the model reads to decide what to
  put there. Declare the shape as a class and annotate it `@GenUiData`, which
  generates the same object schema with the descriptions in it. The build
  error says so.
- Callbacks with more than one argument, and one-argument callbacks whose value
  is not a `String`, a number, a `bool` or an enum. A single scalar argument is
  supported through [`@GenUiWrites`](#controls-the-user-operates-genuiwrites).
- Widgets or callbacks used as fields of a `@GenUiData` class, and data
  classes that reference themselves.
- A property named `id`, `component`, `accessibility` or `weight`, which every
  component takes, and, on a widget with `@GenUiChecked`, one named `checks`,
  `isValid`, `validationErrors`, `validationResults` or `validationPending`,
  where a2ui_core writes what the checks say. Rename the wire key with
  `@GenUiProp(name: ...)`.

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
- 0.15: built on a2ui_flutter 0.2 and a2ui_core 0.6, which replace genui. A
  generated component is a `GenUiComponent`, its examples reach the agent
  through the catalog's instructions, and every tool follows a
  `MessageProcessor`. Every generated component also takes `accessibility`,
  whose label and description a2ui_flutter applies to whatever the widget
  builds, so an agent labels a generated component the way it labels a basic
  one.
- 0.12: a `@GenUiFunction` may take a `@GenUiData` class, or a list of one, so
  a function that works on an object no longer has to take it apart into
  scalars. A property, a field or an argument may also be a `Map<String, V>`,
  for the case where the keys are the agent's to choose rather than part of
  the contract.
- 0.11: `genUiFuzz` renders everything the catalog's schema allows and reports
  what broke; `genUiCoverage` reads a corpus of sessions and says which part of
  the catalog the agent has never used, and what that part costs every request.
  Few-shot samples now read like the property they are in.
- 0.10: `@GenUiChecked` — a component may carry the validation rules the agent
  attached to it, and a parameter receives the message of the first one that
  fails. Each rule is evaluated on its own, so the sentence the agent wrote is
  what the person reads.
- 0.9: `@GenUiFunction` — a top-level Dart function becomes a catalog function,
  so the agent can compute a value with `{"call": ...}` instead of only
  composing components. The argument schema, the return type and the argument
  reading all come from the signature, and the assembled catalog and the
  exported `catalog.json` pick the functions up on their own.
- Proposed next: smarter example generation, where the author's own default
  values and the property description feed the sample instead of the fixed
  `42` / `Sample <name>` placeholders.

## Migrating from genui

genui is being redesigned as a2ui_flutter, and genui_gen 0.15 moves with it.
An app cannot have both renderers, so it moves at once. An app that stays on
genui keeps genui_gen 0.14.x, and genui_gen_builder 0.14.0 still generates
genui code for it: the builder reads which renderer the genui_gen it resolves
is built on.

1. **Dependencies.** Replace `genui` with `a2ui_flutter`, and move both
   packages up. a2ui_flutter needs Flutter 3.38 or later.

   ```yaml
   dependencies:
     a2ui_core: ^0.6.0     # only if the app imports it, as MessageProcessor needs
     a2ui_flutter: ^0.2.0
     genui_gen: ^0.15.0

   dev_dependencies:
     build_runner: ^2.15.0
     genui_gen_builder: ^0.14.0
   ```

2. **Regenerate.** The variables keep their names (`productCardCatalogItem`,
   `genUiCatalogItems`, `genUiCatalogFunctions`, `genUiCatalog`), so code that
   names them only changes the types around them. Parts generated for genui and
   for a2ui_flutter cannot share a catalog, and the build says so if a stale
   one is left over.

   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```

3. **Compose the catalog.** `copyWith` on the generated catalog becomes
   `derive` on the basic one:

   ```dart
   // genui
   final catalog = genUiCatalog.copyWith(
     newItems: BasicCatalogItems.asCatalog().items.toList(),
     newFunctions: BasicCatalogItems.asCatalog().functions.toList(),
   );

   // a2ui_flutter
   final catalog = basicCatalog().derive(
     catalogId: genUiCatalog.id,
     addComponents: genUiCatalogItems,
     addFunctions: genUiCatalogFunctions,
     instructions: genUiCatalog.instructions,
   );
   ```

4. **Render.** The `SurfaceController` becomes a `MessageProcessor`, the
   `Surface` widget an `A2uiSurface`, and the controller's `onSubmit` becomes
   `processor.model.onAction`, as in
   [step 5 of the quickstart](#5-render-what-the-agent-sends). Every message the
   agent sends names its protocol version (`"version": "v0.9"`).

5. **The tools take the processor.** `GenUiTraceRecorder.attach(processor, ...)`
   records what goes through `recorder.processMessages(...)`, which replaces
   `handleMessage`. `GenUiInspector` takes `processor:` instead of
   `controller:`, and `GenUiExampleSurface` takes `component:` instead of
   `item:`, plus an optional `onAction:` for the actions its example sends.
   genui's `DebugCatalogView` is `GenUiCatalogView` in
   `inspector.dart`. `genUiFuzz`, `genUiCoverage` and `GenUiTracePlayer` take
   the composed catalog, and `genUiCatalog.id` replaces
   `genUiCatalog.catalogId`.

6. **Hand-written code.** a2ui_core resolves every property against the
   schema before the builder runs, so the helpers that bound values, ran
   actions, built children and evaluated checks are gone:

   | genui_gen 0.14 | genui_gen 0.15 |
   |---|---|
   | `CatalogItem` | `GenUiComponent`, or a2ui_flutter's `ComponentImplementation`: `dataSchema` is `schema`, `widgetBuilder: (ctx)` is `builder: (context, node, props, buildChild)`, and `exampleData` is `examples`, a list of JSON strings |
   | genui's `A2uiSchemas` | `GenUiSchemas` inside `GenUiSchemas.component(...)`, the shapes a2ui_core resolves a property by |
   | `GenUiBindings`, `GenUiBinding`, `GenUiValues` | `props.string(...)`, `props.number(...)`, `props.boolean(...)`, `props.value(...)`: the property arrives resolved |
   | `genUiActionHandler(ctx, data['onTap'])` | `props.action('onTap')` |
   | `ctx.buildChild(id)`, `genUiTemplateChildren`, `genUiTemplatePath` | `buildChild(node)` for `props.child(...)` and for each of `props.children(...)`, which a2ui_core has already expanded from a template |
   | `genUiValueWriter`, `genUiWritePath`, `genUiWriteReference` | `genUiWriter<T>(context, props, 'property')`, `null` for a literal |
   | `GenUiChecks` | `GenUiSchemas.checks()` in the schema, then `props.isValid` and `props.validationErrors` |
   | `genUiReportMissing`, `genUiResetMissingReports` | the schema's `required` list, which a2ui_core enforces when the message arrives; for a field missing from bound data, `genUiMissingIn(context, node, 'property')` |
   | `ClientFunction`, `ClientFunctionReturnType` | `FunctionImplementation` or `GenUiClientFunction`, whose body now gets a2ui_core's `DataContext`, and `A2uiReturnType` |
   | `GenUiDecoder<T>`, `JsonMap` | `T Function(Map<String, Object?>)`, `Map<String, Object?>` |

   The coercions (`genUiAsString` and the rest), `GenUiMissingFieldReporter`,
   `genUiMissingField`, `genUiNestedField`, `GenUiCheckResult` and
   `genUiCatalogJson` keep their names.

What behaves differently:

- A component missing a required property, or carrying one the widget does not
  take, is rejected when its message arrives, where genui_gen 0.14 rendered a
  missing one with a fallback and reported it.
- A `@GenUiWrites` property sent as a literal is read-only, as on a basic
  control, rather than written to `<componentId>.<property>`.
- A `checks` rule whose binding holds nothing yet fails rather than passing.
- A template's children are keyed by their path, so widget state stays with a
  position in the list rather than with an entry.
- `isImplicitlyFlexible` has no effect: the agent gives a generated component
  a `weight`, as it does a basic one.
- Some names are now build errors, because a2ui_core reads a meaning into
  them; see [Limitations](#limitations-015) and the data class
  [rules](#rules-for-a-data-class).

`genUiCatalogDiff` reads a `catalog.json` written on genui the same way as one
written on a2ui_flutter, so diff the one you published against the new catalog
before you ship. For the example app it finds no breaking change.

## Compatibility

- `a2ui_flutter ^0.2.0`, with the `a2ui_core ^0.6.0` it needs
- Flutter `>=3.38.0`
- Dart `>=3.10.0 <4.0.0`
- `build_runner ^2.15.0`, `source_gen ^4.1.0`, `analyzer >=10.0.0 <15.0.0`

a2ui_core and a2ui_flutter live in
[a2ui-project/a2ui](https://github.com/a2ui-project/a2ui) and are pre-1.0;
their APIs still move between minor versions. This package tracks them and
bumps its constraints when they break. If you are on a newer a2ui_flutter than
the constraint allows, open an issue. For genui, see
[Migrating from genui](#migrating-from-genui).

## Packages

| Package | Put it in | What it holds |
|---|---|---|
| [`genui_gen`](packages/genui_gen) | `dependencies` | the annotations, `GenUiComponent`, the helpers the generated code calls, and the testing, tracing and inspector libraries |
| [`genui_gen_builder`](packages/genui_gen_builder) | `dev_dependencies` | the `build_runner` generator, and the aggregating builder that emits `genui_catalog.g.dart` |
| [`example`](example) | - | eight annotated widgets, a `@GenUiData` class and three functions, rendered through a2ui_flutter with a scripted agent, the inspector and a replayable session |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

Diego Alejandro López Camacho
