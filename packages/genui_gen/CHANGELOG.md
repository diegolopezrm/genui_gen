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

