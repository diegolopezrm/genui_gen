# genui_gen

[![pub package](https://img.shields.io/pub/v/genui_gen.svg?label=genui_gen&color=0175C2)](https://pub.dev/packages/genui_gen)
[![builder](https://img.shields.io/pub/v/genui_gen_builder.svg?label=genui_gen_builder&color=0175C2)](https://pub.dev/packages/genui_gen_builder)
[![pub points](https://img.shields.io/pub/points/genui_gen?label=pub%20points)](https://pub.dev/packages/genui_gen/score)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/diegolopezrm/genui_gen/blob/main/LICENSE)

Annotate a Flutter widget you already have. The
[a2ui_flutter](https://pub.dev/packages/a2ui_flutter) component an agent
composes against (JSON schema, widget builder and examples) is derived from the
widget's constructor, so it cannot drift from the widget it describes.

**[See it end to end, with a recorded agent session you can step through →](https://diegolopezrm.github.io/genui_gen/)**

Or see all of it in one app: [Quincena](https://github.com/diegolopezrm/quincena)
is personal finance where an agent composes every answer from a catalog
generated with this package (still on genui_gen 0.14 and genui).
[It runs in the browser](https://diegolopezrm.github.io/quincena/), no key
needed.

Coming from genui? See [Migrating from genui](#migrating-from-genui).

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

Every property takes a literal or a `{"path": ...}` binding, because its schema
is one of A2UI's dynamic types: a2ui_core resolves it against the data model
before the generated builder runs, and rebuilds the widget when the value
changes. An action is the closure a2ui_core resolved, the same kind the basic
`Button` calls.

Rename the parameter and the generated part changes in review, or the build
fails. There is no second source of truth to keep in sync.

## Install

```yaml
dependencies:
  a2ui_core: ^0.7.0
  a2ui_flutter: ^0.3.0
  genui_gen: ^0.15.0

dev_dependencies:
  build_runner: ^2.15.0
  genui_gen_builder: ^0.14.0
```

a2ui_flutter is the renderer, needs Flutter 3.38 or later, and brings a2ui_core,
the protocol core, with it. `a2ui_core` is listed only because the app imports
it for `MessageProcessor`; a package that only declares components can leave it
out.

This package is the runtime half of the pair: the annotations, and the helpers
the generated code calls. The generator itself lives in
[`genui_gen_builder`](https://pub.dev/packages/genui_gen_builder) and belongs in
`dev_dependencies`.

The generated code is a `part` of your file and names `GenUiComponent`,
`GenUiSchemas` and, for lists, maps and data classes, `S` from
`json_schema_builder`. `genui_gen` exports all of them, which is why you do not
depend on `json_schema_builder` directly. If `S` collides with another
one-letter name in a file (a generated localization class, say), import
`genui_gen` there with `hide S`.

## Annotate

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
  Widget build(BuildContext context) => /* ... */ const SizedBox();
}
```

```sh
dart run build_runner build
```

The generated part declares `productCardCatalogItem`, a `GenUiComponent`: an
a2ui_flutter `ComponentImplementation` that also keeps the examples the
generator wrote.

## Register the catalog

The builder also writes `lib/genui_catalog.g.dart`, holding every annotated
widget in the package, sorted by name, every annotated function and, with a
catalog id, the catalog they make. Composing it with the basic catalog stays
one call whatever the app grows into:

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

Then render what the agent sends:

```dart
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';

final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [catalog],
);
processor.model.onAction.subscribe((action) => agent.send(action));

processor.processMessages(jsonDecode(line)); // every message the agent sends

A2uiSurface(surface: processor.model.getSurface('main')!)
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

Without it the file declares the two lists and no `genUiCatalog`, since an
a2ui_flutter catalog cannot exist without an id.

A v0.9 surface draws on one catalog, so the generated components join the basic
catalog: the generated examples reference the basic `Text` component for child
widgets. `derive` keeps the basic components, their functions and the
definitions they refer to, which a catalog assembled by hand from
`BasicComponents.all` loses. It does not carry instructions over, so the last
argument passes the ones that show the agent an example of each component. For
protocol v1.0, import `package:a2ui_flutter/basic_catalog.dart` instead; the
generated components render on either.

## What a property can be

| Dart parameter type | Schema emitted | Passed to the constructor as |
|---|---|---|
| `String`, `String?` | `GenUiSchemas.string` | `props.string(name)` |
| `int`, `double`, `num` (+`?`) | `GenUiSchemas.number` | `props.number(name)`, with `toInt()` for an `int` |
| `bool`, `bool?` | `GenUiSchemas.boolean` | `props.boolean(name)` |
| any `enum` (+`?`) | `GenUiSchemas.string(enumValues: ...)` | `E.values.asNameMap()[value]` |
| `List<String>` (+`?`) | `GenUiSchemas.stringList` | `List<String>` |
| `List<int>`, `List<double>`, `List<num>` (+`?`) | `GenUiSchemas.list(items: S.number())` | entries converted per element |
| `List<E>` (+`?`) for an enum `E` | `GenUiSchemas.list` carrying the enum's names | one `E` per entry; an unknown name is dropped |
| a `@GenUiData` class (+`?`) | `GenUiSchemas.object(literal: <its object schema>)` | the decoded instance |
| `List<T>` (+`?`) where `T` is `@GenUiData` | `GenUiSchemas.list(items: <T schema>)` | one decoded `T` per entry |
| `Map<String, V>` (+`?`), `V` a scalar, an enum or `Object?` | `GenUiSchemas.object` around an object schema with `additionalProperties` | the coerced `Map` |
| `Widget`, `Widget?` | `GenUiSchemas.componentId` | the child node in `props.child(name)`, built with `buildChild` |
| `List<Widget>` (+`?`) | `GenUiSchemas.componentIdList`, or `GenUiSchemas.childList` for a template, see below | `props.children(name).map(buildChild)` |
| `VoidCallback`, `void Function()` (+`?`) | `GenUiSchemas.action` | `props.action(name)` |
| `void Function(T)` marked `@GenUiWrites` | nothing; it is not a property | a callback from `genUiWriter` that writes the user's value into the data model |
| `Key? key`, `super.key` | skipped | not passed |
| anything else | build error naming the widget, parameter and type | — |

Each schema is a shape a2ui_core recognises, which is how it knows to resolve
the property before the builder runs. `GenUiSchemas.component` wraps them, adds
`accessibility` and `weight`, which every basic component takes, and rejects
any other property, so the agent cannot invent one. A required property the
model leaves out is rejected the same way, when the message arrives. The
fallback the builder carries covers a property bound to a path that holds
nothing yet.

The full rules live in
[`genui_gen_builder`'s README](https://pub.dev/packages/genui_gen_builder).

## Controls the user operates

A plain property is read-only: the model puts a value there and the widget
displays it. A control has to report the new value back, which in A2UI means
writing it into the surface's data model, as the basic `TextField`, `Slider`
and `CheckBox` do. `@GenUiWrites` gives an annotated widget the same ability:

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
Sent as a literal, the property is read-only, as on a basic control: a nullable
callback receives `null`, so the widget can show itself disabled. The generated
example binds it to a path for that reason, since an agent copies the examples
it is shown.

## Validation the agent writes

A2UI lets the agent attach rules to an input component. A `CheckRule` is a
condition and the message to show when it fails, and both are required. The
rules belong to the agent, because what counts as valid depends on what it is
asking for. A widget only has to be willing to say so:

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
  // ...
}
```

`@GenUiChecked` adds a `checks` property to the schema, so the model may send
rules, and hands that parameter the answer. A `String?` takes the message of
the first failing rule, a `bool` takes whether every rule passes, and a
`GenUiCheckResult` takes both.

a2ui_core evaluates each rule on its own and keeps its message, which is the
only part of a rule a person ever reads. Together with `@GenUiWrites` the loop
closes without the agent in it, since the user's value and the rule resolve
against the same path.

The conditions call the basic catalog's functions, which `derive` keeps when
you compose your catalog.

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

One row is built per entry at `/tasks`, each reading its own entry. A new
entry adds a row with nobody asked. It is off by default, and the property
still accepts a plain list of ids.

## Catalog functions

A catalog has two halves. Components are what the agent composes a surface out
of. Functions are what it computes a value with, through the `{"call": ...}`
form any dynamic property already accepts. The basic catalog ships fourteen
(`required`, `regex`, `email`, `formatString` and the rest), and adding one of
your own meant writing a `FunctionImplementation` by hand: the name, the
description, an argument schema spelled out in JSON schema, the return type,
and an `execute` that digs each argument back out of a map and casts it.

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
the Dart return type. Arguments are coerced the way a `@GenUiData` field is, so
a value of the wrong type degrades instead of throwing inside the expression
that called the function.

A `Future<T>` return becomes an async function and a `Stream<T>` a reactive
one, which is how a function with its own source of change (a clock, a
request, a path it watches) keeps answering. Either keeps one answer per set of
arguments, so a2ui_core evaluating the function again does not start the call
over.

The generated functions land in `genUiCatalogFunctions` and in `genUiCatalog`,
and `derive(addFunctions: ...)` puts them next to the basic ones, so adding one
needs no other change. They reach the exported `catalog.json` under
`functions`, in the shape A2UI publishes for its own.

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

A literal object is checked against the schema when its message arrives. One
bound to a path is not, so a required field missing there falls back to a
neutral value and is reported to the agent through `genUiMissingIn`, as a
`VALIDATION_FAILED` error at `/rows/label`.

## Annotations

| Annotation | Target | Purpose |
|---|---|---|
| `@GenUiWidget(description:, name:, constructor:, isImplicitlyFlexible:)` | class | Marks a widget as a catalog component. `description` is required; `isImplicitlyFlexible` only applies on genui. |
| `@GenUiData(description:, constructor:)` | class | Marks a plain data class a widget property may take. |
| `@GenUiProp(description:, name:, ignore:, template:)` | parameter or field | Overrides the schema property; `ignore: true` excludes it, `template: true` lets a `List<Widget>` repeat over a data path. |
| `@GenUiAction(eventName:, description:)` | parameter or field | Customizes a `VoidCallback` action. |
| `@GenUiWrites('property')` | parameter or field | Makes a one-argument callback write the user's value back to that property's path. |
| `@GenUiChecked()` | parameter or field | Publishes a `checks` property and hands this parameter what the agent's rules say. |
| `@GenUiFunction(description:, name:)` | top-level function | Declares a catalog function the model calls with `{"call": ...}`. |

Descriptions default to the parameter's doc comment, then the field's doc
comment.

## Four libraries

| Import | What it is for |
|---|---|
| `package:genui_gen/genui_gen.dart` | the annotations, `GenUiComponent`, the helpers the generated code calls, and `genUiCatalogJson` |
| `package:genui_gen/testing.dart` | record what a component exposes to a screen reader and fail when it changes; render what the schema allows; audit the catalog; diff it against what you published; weigh what it costs the prompt |
| `package:genui_gen/tracing.dart` | record a real agent session and replay it with no model and no network |
| `package:genui_gen/inspector.dart` | a debug panel over the running session (the tree, the data model, the semantics and the messages), and `GenUiCatalogView`, every example of a catalog on one screen |

### The catalog as a document

An agent learns what it may compose from the catalog. Everything outside this
Flutter process needs it as a document: an agent written in Python, a second
client rendering the same surfaces in SwiftUI, a review that has to answer what
the model was allowed to ask for last Tuesday.

`genUiCatalogJson(catalog, {title, description})` returns the A2UI
`catalog.json` document, which is a2ui_core's `validationSchema` for the
catalog: `catalogId`, the `instructions` with an example of each component,
`components`, `functions` and the `$defs` they refer to, copied in so the
document stands on its own. Pass a title and a description; the document has
neither otherwise.

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
for (final GenUiComponent component in genUiCatalogItems) {
  // pump GenUiExampleSurface(catalog: catalog, component: component), then:
  recorded[component.name] = genUiRenderedSemantics();
}
expect(genUiSemanticsGolden(recorded, File('test/genui_semantics.json')), isNull);
```

`GenUiExampleSurface` sends a component's generated example through a real
`MessageProcessor` and renders it in an `A2uiSurface`, so the recording covers
schema, bindings and actions together. Hand it the composed catalog, which
holds the basic `Text` an example's children use. Re-record a deliberate change
with `GENUI_UPDATE_GOLDENS=1`. Role, name, value, state and actions in
traversal order is the shape A2UI's rendering cases use, so the same file also
says what a renderer of your catalog on another platform would have to
reproduce.

### Rendering what the schema allows

`genUiFuzz` renders everything the catalog's own schema permits and reports
what broke. Every widget test checks the input you had in mind; this checks the
ones a model can send and you did not.

```dart
final findings = await genUiFuzz(catalog: catalog, pump: tester.pumpWidget);
expect(findings, isEmpty, reason: genUiFuzzSummary(findings));
```

It mutates each generated component's own example: a required property left
out, a string where a number was declared, an empty list, two hundred entries,
a binding that never resolves. Every case goes through the catalog's own
validation first, and only one the schema accepts and the widget cannot take is
reported. Each finding carries the exact component the renderer was handed, so
it pastes into a test rather than needing to be rebuilt from a description.
Pointed at genui's basic catalog, back when genui_gen was built on genui, it
reported 69 crashing cases across five components
([a2ui#2872](https://github.com/a2ui-project/a2ui/issues/2872)).

Components that lean on their app, a `ThemeExtension` from the app's theme for
instance, need that app around them or every one fails the same way before any
case runs. Give the fuzzer the app with `host`:

```dart
final findings = await genUiFuzz(
  catalog: catalog,
  pump: tester.pumpWidget,
  host: (surface) => MaterialApp(
    theme: appTheme,
    home: Scaffold(body: SingleChildScrollView(child: surface)),
  ),
);
```

### What the agent actually used

A catalog travels in every request whether the agent composes with it or not.
`genUiCoverage` reads the traces `tracing.dart` records and says which
components earned their place:

```
9 of 26 components used across 5 sessions and 5 surfaces
     21740  37.8%  in every request, for components the agent never asked for
```

It also names the properties never filled and the enum values never chosen. Not
a rule to enforce, since a catalog is written before the conversations that use
it, but the answer to "is this too big" with data instead of intuition.

### Recording a session

Someone reports that the confirm button did nothing. You open the code and
there is no confirm button: a model composed that screen, once, from a context
that will not come back.

```dart
final recorder = GenUiTraceRecorder.attach(
  processor,
  catalogId: catalog.id,
  redact: const ['/user/email'],
);
transport.messages.listen(recorder.processMessages);
// ...
await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
```

The recorder hands each message on to the processor. The trace keeps every
message the agent sent, the data model each time it changed (including writes
the user made that never went back to the agent), and every action or error the
app sent back. `GenUiTracePlayer` and `GenUiTraceView` put it back on screen at
any step, with no model and no network, because A2UI describes interfaces as
data. That is how last week's session becomes this week's regression test.
`redact` names the paths a recording must not keep.

### The panel over the running session

A trace is for the session you already lost. The inspector is for the one in
front of you.

```dart
GenUiInspector(
  processor: processor,
  recorder: recorder,
  child: MyConversation(...),
)
```

Four tabs. **Tree** is what the model built, with the paths each component
binds, and it flags a child reference naming a component the surface does not
have, a component nothing reaches from the root, and one that contains itself.
**Data** is every path, what it holds right now, and which components read it;
it reads both ways, so a path no component reads shows up as payload the agent
paid for and nobody saw, and a path a component binds with nothing behind it
shows up as the usual reason a field renders empty with no error anywhere.
**Semantics** is what a screen reader would announce, taken live, which a
generated screen can get wrong without looking any different. **Messages** is
the session, from a `GenUiTraceRecorder`.

It is gone from a release build: `enabled` defaults to `kDebugMode`, and when
it is false the child is returned untouched. `GenUiSurfaceGraph` is the same
reading with no widgets in it, for a test that wants to assert on the shape of
a surface rather than look at it. `GenUiCatalogView(catalog: catalog)` shows
the catalog rather than a session: every example of every generated component,
each on a surface of its own, with the actions they send passed to its
`onAction`. It runs on the web.

### Checking the contract and the cost

`genUiCatalogDiff` reports what changed for the model between two catalogs,
and which of those changes break a message the agent still knows how to write.
`genUiSemanticsAudit` reads the semantics recording and reports a control with
nothing to announce, a component that reaches assistive technology as nothing
at all, and two controls that announce themselves identically.
`genUiCatalogWeight` says how much of every prompt each component takes up.

## Runtime helpers

Generated code uses these; a hand-written component can too.

- `GenUiComponent` is an a2ui_flutter `ComponentImplementation` that also keeps
  the examples the generator wrote, each a JSON list of components with `root`
  first. The testing tools render them, and `genUiExampleInstructions` writes
  them, as compact JSON under each component's name, into the instructions of
  the generated catalog.
- `GenUiSchemas` builds the shapes a2ui_core resolves a property by: `string`
  (with `enumValues` for an enum), `number`, `boolean`, `stringList`, `list`,
  `object`, `componentId`, `componentIdList`, `childList`, `action` and
  `checks`. A description passed to one replaces the shared type's, so the
  agent reads what the property means here. `GenUiSchemas.component` wraps
  them, adds `accessibility` and `weight`, and rejects any other property.
- `genUiWriter<T>(context, props, property)` backs `@GenUiWrites`: a callback
  that writes the user's value through the binding of `property`, or `null`
  when the property is a literal. A write the data model refuses is reported on
  the surface's `onError` rather than thrown out of a gesture handler.
- `genUiMissingIn(context, node, property)` is the reporter a generated builder
  hands the decoder of a `@GenUiData` property. A required field missing from
  bound data is reported once per component, on the surface's `onError`, as a
  `VALIDATION_FAILED` error at `/<property>/<field>`.
- `GenUiClientFunction`, with `.async` and `.streaming`, is the
  `FunctionImplementation` a `@GenUiFunction` generates. The async and
  streaming forms keep one answer per set of arguments, for the `maxAnswers`
  most recent sets, so a2ui_core evaluating the function again does not start
  the call over.
- `GenUiCheckResult` is what a `@GenUiChecked` parameter of that type receives:
  whether every rule passes, and the message of the first one that fails.
- `genUiAsString`, `genUiAsNum`, `genUiAsBool`, `genUiAsStringList`,
  `genUiAsNumList`, `genUiAsObject`, `genUiAsObjectList`, `genUiAsStringMap`,
  `genUiAsNumMap` and `genUiAsBoolMap` coerce one raw JSON value instead of
  casting it: a numeric string reads as a number, `"true"` as `true`, and a
  value that cannot be read as the type as `null`. Generated decoders call
  them, so a model that sends a number where a string was declared degrades
  rather than throwing a `TypeError` inside `build`.
- `GenUiMissingFieldReporter`, `genUiMissingField` and `genUiNestedField` carry
  the reporting down into a data object, so a field missing from a nested
  object is reported with every level of its path.

The library also exports the renderer types the generated code names
(`ComponentImplementation`, `CatalogImplementation`, `ComponentProps`,
`FunctionImplementation`, `A2uiReturnType`, `CommonSchemas`, `DataContext`) and
`S`, `Schema` and `ObjectSchema` from `json_schema_builder`, so a generated part
needs no other import.

## Migrating from genui

genui is being redesigned as a2ui_flutter, and genui_gen 0.15 moves with it. An
app that stays on genui keeps genui_gen 0.14.x, and genui_gen_builder 0.14.0
still generates genui code for it.

1. Depend on `a2ui_flutter: ^0.3.0` instead of `genui` (and on
   `a2ui_core: ^0.7.0` if the app imports it), on `genui_gen: ^0.15.0` and on
   `genui_gen_builder: ^0.14.0`. a2ui_flutter needs Flutter 3.38 or later.
2. Regenerate with `dart run build_runner build --delete-conflicting-outputs`.
   The generated variables keep their names.
3. Compose with `basicCatalog().derive(...)` where you had
   `genUiCatalog.copyWith(newItems: ..., newFunctions: ...)`, as in
   [Register the catalog](#register-the-catalog).
4. Render with a `MessageProcessor` and an `A2uiSurface` where you had a
   `SurfaceController` and a `Surface`; actions arrive on
   `processor.model.onAction`. The tools follow:
   `GenUiTraceRecorder.attach(processor, ...)` records through
   `recorder.processMessages`, `GenUiInspector` takes `processor:`,
   `GenUiExampleSurface` takes `component:`, and `GenUiCatalogView` stands in
   for genui's `DebugCatalogView`.
5. Hand-written code that called a removed helper reads what a2ui_core already
   resolved:

| genui_gen 0.14 | genui_gen 0.15 |
|---|---|
| `CatalogItem` | `GenUiComponent`, or a2ui_flutter's `ComponentImplementation` |
| `GenUiBindings`, `GenUiBinding`, `GenUiValues` | `props.string(...)`, `props.number(...)`, `props.boolean(...)`, `props.value(...)` |
| `genUiActionHandler` | `props.action(...)` |
| `genUiTemplateChildren`, `genUiTemplatePath` | `props.children(...)`, built with `buildChild` |
| `genUiValueWriter` | `genUiWriter` |
| `GenUiChecks` | `GenUiSchemas.checks()`, then `props.isValid` and `props.validationErrors` |
| `genUiReportMissing` | the schema's `required` list; `genUiMissingIn` for bound data |
| `ClientFunction`, `ClientFunctionReturnType` | `FunctionImplementation` or `GenUiClientFunction`, and `A2uiReturnType` |

The [repository README](https://github.com/diegolopezrm/genui_gen#migrating-from-genui)
walks through it, including what now behaves differently.

## Compatibility

`a2ui_flutter` 0.2 or 0.3 · `a2ui_core` 0.6 or 0.7 · Flutter `>=3.38.0` · Dart
`>=3.10.0 <4.0.0`

a2ui_core and a2ui_flutter live in
[a2ui-project/a2ui](https://github.com/a2ui-project/a2ui) and are pre-1.0;
their APIs still move between minor versions. This package tracks them and
bumps its constraints when they break.

## License

MIT. Copyright Diego Alejandro López Camacho.
