## 0.8.0

- Generates a `ClientFunction` for every top-level function annotated with
  `@GenUiFunction`. The argument schema property names are the parameter
  names, the required list is the set of parameters with no default that are
  not nullable, the descriptions come from the doc comments, the enum values
  come from the enum, and the return type comes from the Dart return type.
  Each argument is read back through the same coercions a `@GenUiData` field
  uses, so a model that sends a string where a number was declared degrades
  instead of throwing inside the expression that called the function.
- A `Future<T>` return is emitted through `GenUiClientFunction.async` and a
  `Stream<T>` through `.streaming`, so a function with its own source of change
  keeps answering.
- `genui_catalog.g.dart` now also declares `genUiCatalogFunctions` and hands it
  to the assembled `Catalog`, so adding a function needs no other change
  anywhere. A package that declares functions and no widgets gets the file too.
- Build errors, each naming the function: a private function, whose generated
  variable no other library could name; a name genui's basic catalog already
  registers, which would replace that function and change what every prompt
  written against it means; an argument that is a widget or a callback, which a
  function has nothing to build or dispatch; a return type the model cannot
  receive; and an empty description.

## 0.7.1

- Documentation only; no generator change.
- Corrected the install instructions, which listed `json_schema_builder` as a
  direct dependency and imported it in the annotated file. It has not been
  needed since `genui_gen` 0.3.0.
- Documented the runtime floor each builder needs. The generator emits calls to
  runtime helpers as they are added, so a new builder against an old
  `genui_gen` generates code that does not compile, and nothing enforces it:
  the builder deliberately does not depend on the runtime. 0.7.x needs
  `genui_gen >= 0.8.0`.
- Added `homepage`, pointing at https://diegolopezrm.github.io/genui_gen/.

## 0.7.0

- Added `@GenUiProp(template: true)`, which lets a `List<Widget>` property
  accept a child template as well as a list of ids:

  ```dart
  @GenUiWidget(description: 'A titled list of rows.')
  class TaskList extends StatelessWidget {
    const TaskList({
      super.key,
      required this.title,
      @GenUiProp(template: true) required this.rows,
    });
  ```

  The property's schema becomes `A2uiSchemas.componentArrayReference()`, the
  path the template repeats over is bound so new entries rebuild the children,
  and the children are built with each entry as its own data context.

- Off by default: the schema a template property publishes is not the one a
  prompt tuned against the previous version was written for, so turning it on
  is the author's call.
- `@GenUiProp(template: true)` on anything but a `List<Widget>` is a build
  error naming the parameter.

## 0.6.0

- `lib/genui_catalog.g.dart` now declares the assembled `Catalog` as well as
  the list of items, so an app hands genui the catalog directly instead of
  wrapping the list by hand:

  ```dart
  final catalog = genUiCatalog.copyWith(
    newItems: BasicCatalogItems.asCatalog().items.toList(),
  );
  ```

- Added the `catalog_id` build option, which becomes that catalog's id:

  ```yaml
  targets:
    $default:
      builders:
        genui_gen_builder:genui_catalog:
          options:
            catalog_id: com.example.app
  ```

  It cannot be derived here — the id names the catalog to the agent that
  composes against it and the clients that render it, which is not something a
  generator can invent. Without it the catalog is still assembled, just without
  an id, and the generated file says how to set one.
- A `catalog_id` that is not a string, or that could not survive being written
  into the generated file, is a build error naming the option rather than
  broken Dart or an id nobody chose.

## 0.5.0

- Added an aggregating builder. Every `CatalogItem` generated in the package is
  collected into one `lib/genui_catalog.g.dart`, which declares
  `genUiCatalogItems` and imports the libraries that hold them. Registering a
  catalog was otherwise a hand-maintained import list plus a hand-maintained
  list of variable names — the same drift this package exists to remove, one
  level up, since adding a `@GenUiWidget` left the catalog silently as it was.

  ```dart
  import 'genui_catalog.g.dart';

  final catalog = Catalog([
    ...genUiCatalogItems,
    ...BasicCatalogItems.asCatalog().items,
  ], catalogId: 'com.example.app');
  ```

- The list is sorted by variable name, so the file does not reorder itself
  between builds, and a package with nothing annotated gets no file rather than
  an empty one.
- Two libraries whose generated items would arrive under the same name are now
  a build error naming both files. The per-library generator already rejected a
  collision inside one library; across libraries the two only meet in the
  aggregate, which names each unprefixed.
- A `@GenUiWidget(name: '...')` on a private class generates a private
  variable, which no other library can name. It is left out of the aggregate
  with a warning that says why, rather than emitting a file that does not
  compile.
- `genui_gen` stays at 0.4.0. This release changes the builder only: the
  generated file imports `package:genui/genui.dart` and nothing from the
  annotations package.

## 0.4.0

- Recognises `@GenUiWrites('<property>')` on a `void Function(T)` parameter and
  emits a callback that writes the user's value into the data model. The
  callback is left out of the schema and out of `required`, since the model
  never supplies it; what the model supplies is the binding on the property it
  writes to.
- A property some callback writes to is read back through the path it is
  written to (`genUiWriteReference`), with the literal the model sent as the
  fallback until that path holds something. Enums are written as their name,
  matching how they are read back.
- Appends a sentence to the written property's schema description, so the model
  knows that binding it to a path is how the answer is read.
- New build errors, each naming both sides: a `void Function(T)` with no
  `@GenUiWrites`, `@GenUiWrites` on something that is not such a callback, a
  property the widget does not have (listing the ones it could write to), a
  property that cannot be written back, a callback whose argument does not
  match the property, and a nullable argument.
- A callback with more than one argument, or one whose argument is not a
  `String`, a number, a `bool` or an enum, stays unsupported and keeps the
  general message.
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
- Additive release: widgets that only use 0.2 types generate identical code.
- Requires `genui_gen` 0.3.0 or newer: generated decoders call
  `genUiAsNumList`, and generated builders call `GenUiBinding.numberList`.
- The builder now warns when a component name shadows one of genui's basic
  catalog items (`Card`, `Row`, `Image`, ...). `Text` remains an error,
  because generated examples compose it for child components.

## 0.2.0

- Added `@GenUiData`: a plain Dart class annotated with it gets a generated
  `final ObjectSchema <name>GenUiSchema` and a
  `<Type> <name>FromGenUiJson(Map<String, Object?> json, [reporter])` decoder
  in the same `.genui.dart` part, and may then be used as a widget parameter.
  Requires `genui_gen` 0.2.0 or newer for the runtime helpers it calls.
- A widget parameter may now be a `@GenUiData` class or a `List` of one. The
  object property is resolved through `GenUiBinding.object` /
  `GenUiBinding.objectList` (so `{"path": ...}` and `{"call": ...}` work on the
  whole object) and decoded with the generated decoder.
- Data-class fields use the plain `S.string` / `S.integer` / `S.number` /
  `S.boolean` / `S.list` schemas instead of `A2uiSchemas.*Reference`: the
  values inside a data object are literals the model emits, not per-field
  bindings. An `int` field is `S.integer`, so a fractional value is rejected
  by validation rather than silently truncated.
- Generated decoders never cast. Fields go through the `genUiAs*` coercions
  exported by `genui_gen`, so a model that puts a number where a string was
  declared degrades exactly as it does for a widget property instead of
  throwing a `TypeError` inside `build`. Required fields that fell back are
  reported through `genUiReportMissing` as `<property>.<field>`, but only once
  the property itself has resolved, so a data binding that is still pending
  does not turn into one false field error per required field.
- The schema of a data property is a `oneOf` of the object schema, a data
  binding and a function call, and a list property uses
  `A2uiSchemas.listOrReference`. The builder resolves those forms through
  `BoundObject` / `BoundList`, so the schema now says so and a data-bound
  table validates.
- Data classes may nest: a nested schema is inlined by reference to its own
  generated variable (never a `$ref`) and the decoder calls the nested decoder.
  Enums and `List<String>` work inside a data class.
- A data class may live in another library, as long as the widget's library
  imports it without a prefix and that library declares its own
  `part '<file>.genui.dart';`. Both are checked, with a build error naming the
  fix.
- New build errors: a `Widget`, `List<Widget>` or callback field inside a
  `@GenUiData` class, a data-class cycle (the message names the whole path), a
  `@GenUiData` class with no usable constructor, a generic `@GenUiData` class,
  a field whose wire key would be the reserved `path` or `call`, a class
  carrying both `@GenUiWidget` and `@GenUiData`, two data classes whose
  lower-camel names collide (in one library or across the libraries one
  generated part refers to), a data class imported with a `show` / `hide`
  combinator that hides its generated schema and decoder, and a parameter whose
  type does not resolve at all (usually a missing import or an ambiguous name).
  An unsupported parameter type that is a class of your own now points at
  `@GenUiData`.
- A constructor parameter called `key` is kept inside a `@GenUiData` class: a
  data class has no `super.key` to skip, and dropping it produced a decoder
  that did not compile.
- Generated examples include a sample object for a data property and two
  sample objects for a list property. The entries of a list are numbered
  (`Sample label 1`, `Sample label 2`), their numbers are spread (`42`/`43`,
  `42.5`/`43.5`) and their enum fields walk the enum instead of repeating the
  first value, so the example shows the model that a field varies from row to
  row. A standalone object property is entry 0 and keeps the 0.1 samples.
- A doc comment or `@GenUiProp(description:)` on a property or field whose
  type is a data class is carried into the schema: on a widget property it
  becomes the description of the `oneOf` wrapper, and on a field of another
  data class the inlined schema is copied with that description in place of
  the class's own `@GenUiData(description:)`.
- Output for widgets that only use 0.1 types is unchanged, byte for byte.

## 0.1.2

- Corrected the declared dependency lower bounds so they match what the
  generator actually requires: `source_gen` >= 4.1.0 (for
  `TypeChecker.typeNamedLiterally`) and `analyzer` >= 10.0.0 (where the element
  API the generator uses is no longer marked experimental). The previous
  0.1.0/0.1.1 lower bounds did not resolve to a working build.

