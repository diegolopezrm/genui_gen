## 0.9.0

- Added `@GenUiFunction`, the other half of an A2UI catalog. A catalog holds
  components, which the agent composes a surface out of, and functions, which
  it computes a value with through the `{"call": ...}` form any bound property
  already accepts. genui ships fourteen of them and an app could add its own
  only by writing a `ClientFunction` by hand: the name, the description, an
  `argumentSchema` spelled out in JSON schema, the return type, and an
  `execute` that digs each argument back out of a map and casts it. That is
  the same drift this package removes from components, one half of the catalog
  over.
- Added `GenUiClientFunction`, which the generated code builds: a
  `ClientFunction` whose body is a callback. Three constructors, for a function
  that answers immediately, one that answers once later (`.async`), and one
  that keeps answering as its own sources change (`.streaming`). A throw inside
  the body becomes an error on the stream rather than an exception out of the
  expression that called it.
- `ClientFunction`, `ClientFunctionReturnType` and `A2uiSchemas` are now
  re-exported, for the same reason `S` is: a file that declares only catalog
  functions names them in its generated part and should not have to import
  genui to get them.

## 0.8.1

- Documentation only; no API change.
- Corrected the install instructions. They still listed `json_schema_builder`
  as a direct dependency and imported it in the annotated file, which stopped
  being true in 0.3.0 when this package began re-exporting `S`, `Schema` and
  `ObjectSchema` for exactly that reason.
- The README now covers what 0.4 through 0.8 added: `@GenUiWrites`, child
  templates, lists of scalars and enums, and the assembled `genUiCatalog` with
  its `catalog_id`.
- Added `homepage`, pointing at https://diegolopezrm.github.io/genui_gen/.

## 0.8.0

- Added `genUiTemplateChildren` and `genUiTemplatePath`, the runtime half of
  child templates. A2UI describes the children of a component in two ways: a
  list of ids the agent wrote out, or `{"componentId": "row", "path": "/rows"}`
  repeated once per entry of the data model. The second is what makes a list
  that grows when the agent sends data rather than a new surface, and a
  generated widget could not accept it.
- Each template child reads its own entry: the child of `/rows` at index 2
  binds `title` against `/rows/2/title`, so one component describes every row.
  Children are keyed by entry rather than by position, so a row removed from
  the middle takes its state with it instead of handing it to the row below.
- Added `GenUiBinding.value` and `GenUiValues.raw`, which resolve a path and
  hand back what it holds without coercing it. The typed bindings are right
  for a widget property; a template needs the list or the map itself.

## 0.7.0

- Added `package:genui_gen/tracing.dart`: record an agent session and replay
  it. A generative interface has a problem an ordinary app does not — the
  screen that failed is not in the source, because a model composed it once
  from a context that will not come back — and a trace is that session, kept.
  `GenUiTraceRecorder.attach` keeps every message the agent sent, the contents
  of each surface's data model whenever they changed, and every action the app
  sent back; `GenUiTracePlayer` replays it with no model and no network, and
  `GenUiTraceView` shows it, at any step.

  ```dart
  final player = GenUiTracePlayer(trace, catalog: genUiCatalog)..seek(7);
  await tester.pumpWidget(MaterialApp(home: GenUiTraceView(player: player)));
  ```

  Because the replay renders against the app's current catalog, an old session
  is also a regression test: a catalog change that breaks a real conversation
  fails before a user finds it.

- `redact` names the data model paths a recording must not keep. A session
  records what the user typed, so the field holding an email has to be named
  before the first recording rather than after the first leak.
- Added `genUiCatalogDiff`, which reports what changed between two catalog
  documents from where it matters: the model. A removed component, a new
  required property, a dropped enum value and a changed type are breaking,
  because the agent's prompt still describes the old one. A new optional
  property and a new enum value are not.
- Added `genUiSemanticsAudit`, which reads the recording the golden test
  already keeps and reports what a screen reader user could not work with: a
  control with nothing to announce, a component that reaches assistive
  technology as nothing at all, two controls that announce themselves
  identically.
- Added `genUiCatalogWeight`, which says how much of every prompt each
  component takes up. A catalog is sent on every request and nothing makes its
  cost visible.
- `GenUiSemanticNode` now records `tooltip` alongside `name`. A control named
  only by a tooltip is not unnamed, but it is not named the same way either,
  and the recording shows which of the two it has.
- The example app records a session with its own widgets, checks its catalog
  against the published one, and lists what the basic catalog gives a screen
  reader today: an audio player whose play button and two sliders announce
  nothing, an image that exposes nothing at all, and a slider with a `label`
  the catalog never passes on.

## 0.6.0

- Added `package:genui_gen/testing.dart`, which checks the half of a catalog
  the schema cannot: what a generated component actually exposes to the person
  using it. `genUiSemantics` reads the role, name, value, state and actions of
  a rendered surface, in traversal order; `genUiSemanticsGolden` records that
  into a JSON file and fails when it changes; `GenUiExampleSurface` renders one
  item's generated example through a real `SurfaceController`, so the test
  covers the whole path — schema, bindings and actions — rather than the widget
  alone.

  ```dart
  expect(
    genUiSemanticsGolden(recorded, File('test/genui_semantics.json')),
    isNull,
  );
  ```

- The recorded file is checked in and read in review. It is the answer to
  "what can the model make this app announce, press or report", which is the
  part of a change that a Dart diff does not show. Re-record a deliberate
  change with `GENUI_UPDATE_GOLDENS=1`.
- The file is written in the shape A2UI's rendering cases use — role, name,
  value, state, actions — so the same recording describes the catalog to a
  renderer on another platform.
- `example/test/genui_semantics.json` records the example app's catalog, and
  `example/test/genui_semantics_test.dart` is the test to copy.
- `a2ui_core` is now a dependency: `GenUiExampleSurface` builds the surface
  from the same message types genui takes.

## 0.5.0

- Added `genUiCatalogJson` and `genUiCatalogJsonString`, which turn a `Catalog`
  into the A2UI `catalog.json` document that describes it. Inside the app genui
  puts the catalog in the prompt for you; everything outside this Flutter
  process needs it as a document — an agent written in Python, a second client
  rendering the same surfaces in SwiftUI, a review that has to answer what the
  model was allowed to ask for last Tuesday. The result is the shape A2UI
  publishes for its own basic catalog: `catalogId`, `components`, `functions`
  when the catalog has any, and the `$defs` a renderer resolves a component
  against.

  ```dart
  final json = genUiCatalogJsonString(genUiCatalog, title: 'Acme catalog');
  ```

- The export takes a `title` and a `description` of its own. genui fills in
  `A2UI Catalog` and `Custom catalog of A2UI components and functions.` for
  every catalog ever generated, and an agent handed three of them has nothing
  else to tell them apart by.
- A catalog with no `catalogId` is rejected rather than exported. A surface
  names the catalog it was built against, so a document without an id
  describes components that nothing can ask for.
- `example/catalog.json` is generated from a test, and the README shows the
  pattern: write the file under `--update-goldens` and compare against it
  otherwise, so the document in the repository cannot fall behind the widgets
  and a reviewer sees what a new `@GenUiWidget` exposed to the model.

## 0.4.0

- Added `@GenUiWrites`, which makes a control the user operates annotatable. A
  `void Function(T)` parameter marked `@GenUiWrites('<property>')` receives a
  callback that writes the user's value into the surface's data model, at the
  path the model bound `<property>` to. It is what genui's own `TextField`,
  `Slider`, `CheckBox`, `ChoicePicker`, `DateTimeInput` and `Tabs` already do,
  and until now an annotated widget had no way to express it: a property was
  read-only, so a switch or a text field could not be annotated at all. `T` may
  be a `String`, an `int`, a `double`, a `num`, a `bool` or an enum.
- A property some callback writes to is now read back through the same path it
  is written to, so the control reflects what the user just did. A literal the
  model sent is still honoured until that path holds something, the way
  `TextField` seeds itself from its initial value. When the model sends a
  literal rather than a binding there is no path it named, so the value is
  written to `<componentId>.<property>` — the fallback the core catalog uses —
  and the control stays interactive.
- The description of a written property gains a sentence saying so. The
  callback itself is not in the schema, because the model never supplies it, so
  the model would otherwise have no way to know that binding the property to a
  path is how it reads the answer.
- Added the runtime helpers `genUiValueWriter`, `genUiWritePath` and
  `genUiWriteReference`, called by generated code. A write the data model
  refuses — a non-numeric segment on a list, an index out of bounds — is
  reported through `ctx.reportError` rather than thrown out of a gesture
  handler, exactly as a failed action is.
- The callback's argument may not be nullable. A2UI has no agreed meaning for
  writing `null` to a path, so `ValueChanged<String?>` is a build error rather
  than a silent choice between "clear it" and "store null".
- Additive release: a widget that uses only 0.3 types generates identical code.

## 0.3.0

- Added lists of scalars: a `@GenUiWidget` parameter or `@GenUiData` field may
  now be a `List<int>`, `List<double>`, `List<num>`, or a `List<E>` for an
  enum `E`. Each was a build error in 0.2.
- Added `GenUiBinding.numberList` and `GenUiValues.numberList`, resolved
  through genui's `BoundList`. Entries that are not numbers are dropped, and a
  numeric string is parsed, the way the core catalog's number binding does.
- Added the coercion helper `genUiAsNumList`, used by generated decoders for
  numeric list fields of a `@GenUiData` class.
- A list of enums is carried as strings and mapped back by name. A name the
  enum does not declare is dropped rather than defaulted: the list is the
  model's, and one bad entry should not silently become a value the author
  never wrote.
- Re-exported `S`, `Schema` and `ObjectSchema` from `json_schema_builder`, so
  an annotated file imports `genui_gen` alone and `json_schema_builder` stops
  being a direct dependency of consumers. `show`n rather than exported
  wholesale; if `S` collides with another one-letter name, import with
  `hide S`.
- `json_schema_builder` moved from dev_dependencies to dependencies, since
  those three names are now part of this package's public API.
- Additive release: widgets that only use 0.2 types generate identical code.

## 0.2.0

- Added `@GenUiData`, marking a plain Dart class as a data shape an annotated
  widget may receive. A `@GenUiWidget` parameter may now be a data class, or a
  `List` of one, so widgets that take rows, points or items are annotatable.
- Added the `GenUiDecoder<T>` typedef used by generated code to rebuild a data
  class from the map the model produced.
- Added `GenUiBinding.object` and `GenUiBinding.objectList`, resolved through
  genui's `BoundObject` and `BoundList`, plus the matching `GenUiValues.object`
  and `GenUiValues.objectList` accessors. `objectList` skips entries that are
  not maps instead of throwing.
- Added the coercion helpers `genUiAsString`, `genUiAsNum`, `genUiAsBool`,
  `genUiAsStringList`, `genUiAsObject` and `genUiAsObjectList`. Generated
  decoders call them instead of casting, so a field of the wrong type degrades
  the way genui's `Bound*` widgets degrade instead of throwing a `TypeError`
  inside `build`.
- Added `GenUiMissingFieldReporter`, `genUiMissingField` and `genUiNestedField`,
  which carry the missing-property report into a data object: a required field
  the model left out of a row reaches the model as `rows.label`.
- Additive release: widgets that only use 0.1 types generate identical code.

## 0.1.2

- Version bump to stay aligned with `genui_gen_builder` 0.1.2. No API changes.

