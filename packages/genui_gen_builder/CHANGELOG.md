## 0.1.0

Initial release.

- `genUiGenBuilder`: a `PartBuilder` that writes `<file>.genui.dart` for every
  library containing `@GenUiWidget` classes.
- Derives the `CatalogItem` name, `S.object` data schema (with `required`),
  one few-shot example and the widget builder from the annotated constructor.
- Supports `String`, `int`, `double`, `num`, `bool`, enums, `List<String>`,
  `Widget`, `List<Widget>` and `VoidCallback` parameters, each optionally
  nullable; `key` / `super.key` are skipped.
- Honours `@GenUiWidget(name, description, constructor, isImplicitlyFlexible)`,
  `@GenUiProp(description, name, ignore)` and
  `@GenUiAction(eventName, description)`, on parameters or backing fields.
- Descriptions fall back to parameter and field doc comments.
- Required-but-missing values use a fallback and are reported once per
  component through `genUiReportMissing`; the generated builder never throws.
- Default values are parenthesised when they are not a single literal or
  identifier, so conditional and arithmetic defaults compile.
- Generated code is formatter-friendly: example JSON is emitted as an indented
  raw multi-line string and long descriptions are split into adjacent string
  literals so generated lines stay within 80 columns.
- Clear `InvalidGenerationSourceError`s for unsupported types, empty
  descriptions, `ignore` on required parameters or on positional parameters
  that others would shift into, unknown constructors, duplicate property
  names, non-Widget or abstract classes, private classes without a name, the
  reserved name `Text`, colliding variable names, inherited non-literal
  defaults, prefixed enums and missing (or prefix-only) imports.
- Generated example child ids are `child_<prop>` so they cannot collide with
  `root`.
