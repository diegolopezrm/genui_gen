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

