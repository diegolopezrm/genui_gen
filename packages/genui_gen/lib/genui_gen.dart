/// Annotations and runtime helpers for generating genui `CatalogItem`s from
/// your own Flutter widgets.
///
/// Annotate a widget with [GenUiWidget] and run `build_runner` with
/// `genui_gen_builder` to derive the JSON schema, the widget builder and the
/// few-shot examples from the widget's constructor. Because everything is
/// derived from the constructor, the catalog can never drift from the widget.
///
/// The runtime helpers ([GenUiBindings], [GenUiBinding], [GenUiValues],
/// [genUiActionHandler] and [genUiReportMissing]) are used by the generated code and are exported here
/// so that generated parts only need to import this library.
library;

export 'src/actions.dart';
export 'src/annotations.dart';
export 'src/bindings.dart';
export 'src/missing.dart';
