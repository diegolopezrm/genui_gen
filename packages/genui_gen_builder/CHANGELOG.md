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

