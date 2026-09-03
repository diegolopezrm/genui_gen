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

