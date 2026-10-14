/// Annotations and runtime helpers for generating a2ui_flutter components from
/// your own Flutter widgets.
///
/// Annotate a widget with [GenUiWidget] and run `build_runner` with
/// `genui_gen_builder` to derive the JSON schema and the widget builder of a
/// [ComponentImplementation] from the widget's constructor. Because everything
/// is derived from the constructor, the catalog can never drift from the
/// widget.
///
/// Annotate a plain data class with [GenUiData] to let an annotated widget
/// take it, or a list of it, as a property, and a top-level function with
/// [GenUiFunction] to make it a function of the catalog.
///
/// a2ui_core resolves every property of a component against its schema before
/// the widget is built, so the generated builder only reads what it resolved.
/// The helpers it needs for the rest ([GenUiSchemas], [genUiWriter] and
/// [genUiMissingIn]) are exported here, so that generated parts only need to
/// import this library.
///
/// [genUiCatalogJson] and [genUiCatalogJsonString] go the other way: they turn
/// the catalog the generator assembled into the A2UI `catalog.json` document,
/// which is what an agent — or a client written in another language — reads to
/// learn which components it may ask for.
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
/// model that sends a number where a string was declared degrades rather than
/// throwing inside `build`.
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

// Every renderer type generated code names, re-exported for the same reason as
// `S`: a generated part, and the generated catalog, then need nothing but this
// library.
export 'package:a2ui_core/a2ui_core.dart'
    show A2uiReturnType, CommonSchemas, DataContext, FunctionImplementation;
export 'package:a2ui_flutter/a2ui_flutter.dart'
    show CatalogImplementation, ComponentImplementation, ComponentProps;

export 'src/annotations.dart' hide genUiGenTargetsA2uiFlutter;
export 'src/catalog_json.dart';
export 'src/checks.dart';
export 'src/coerce.dart';
export 'src/functions.dart';
export 'src/schemas.dart';
export 'src/writers.dart';
