/// Annotations and runtime helpers for generating genui `CatalogItem`s from
/// your own Flutter widgets.
///
/// Annotate a widget with [GenUiWidget] and run `build_runner` with
/// `genui_gen_builder` to derive the JSON schema, the widget builder and the
/// few-shot examples from the widget's constructor. Because everything is
/// derived from the constructor, the catalog can never drift from the widget.
///
/// Annotate a plain data class with [GenUiData] to let an annotated widget
/// take it, or a list of it, as a property.
///
/// The runtime helpers ([GenUiBindings], [GenUiBinding], [GenUiValues],
/// [GenUiDecoder], [genUiActionHandler] and [genUiReportMissing]) are used by
/// the generated code and are exported here so that generated parts only need
/// to import this library.
///
/// `S`, [Schema] and [ObjectSchema] are re-exported from
/// `package:json_schema_builder`, because the generated part builds its schema
/// with them and shares this library's imports. If `S` collides with another
/// one-letter name in your file (a generated localization class, say), import
/// this library with `hide S`.
///
/// The same goes for the coercion helpers ([genUiAsString], [genUiAsNum],
/// [genUiAsBool], [genUiAsStringList], [genUiAsNumList], [genUiAsObject],
/// [genUiAsObjectList])
/// and the field reporters ([GenUiMissingFieldReporter], [genUiMissingField],
/// [genUiNestedField]): generated decoders call them instead of casting, so a
/// model that sends a number where a string was declared degrades exactly the
/// way genui's `Bound*` widgets do rather than throwing inside `build`.
library;

// Generated parts are `part of` the annotated library, so they build their
// schemas through that library's imports. Re-exporting the three symbols they
// name means an annotated file needs one import rather than two, and
// `json_schema_builder` stops being a direct dependency of every consumer.
//
// Deliberately `show`n rather than a blanket export: a blanket one would put
// StringSchema, ListSchema, ValidationError and the rest into the namespace of
// every file that imports this package.
export 'package:json_schema_builder/json_schema_builder.dart'
    show ObjectSchema, S, Schema;

export 'src/actions.dart';
export 'src/annotations.dart';
export 'src/bindings.dart';
export 'src/coerce.dart';
export 'src/missing.dart';
