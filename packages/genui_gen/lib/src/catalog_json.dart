import 'dart:convert';

import 'package:genui/genui.dart';

/// The A2UI catalog document that describes [catalog].
///
/// A catalog is the contract between the agent and the app: it says which
/// components exist and what each one accepts. genui builds that description
/// in memory to put it in the prompt, but everything outside this Flutter
/// process needs it as a document — an agent written in Python, a second
/// client rendering the same surfaces in SwiftUI, a review that has to answer
/// what the model was allowed to ask for last Tuesday.
///
/// The result is the shape A2UI publishes for its own basic catalog:
/// `catalogId`, `components`, `functions` when the catalog has any, and the
/// `$defs` a renderer resolves a component against.
///
/// Generate it from a test or a tool rather than from the app, so the file in
/// the repository cannot fall behind the widgets:
///
/// ```dart
/// test('catalog.json is up to date', () {
///   expect(
///     File('catalog.json').readAsStringSync(),
///     genUiCatalogJsonString(genUiCatalog),
///     reason: 'Run `dart run tool/write_catalog.dart` to refresh it.',
///   );
/// });
/// ```
///
/// [title] and [description] replace the generic ones genui fills in, which
/// read `A2UI Catalog` and `Custom catalog of A2UI components and functions.`
/// for every catalog ever generated. An agent that is handed three of these
/// has nothing else to tell them apart by.
///
/// Throws an [ArgumentError] when [catalog] has no `catalogId`. That id is how
/// a surface names the catalog it was built against, in `createSurface`, so a
/// document without one describes components that nothing can ask for.
///
/// The `$ref`s in the result point at the shared types on `a2ui.org` for v0.9,
/// the protocol version genui emits, so whatever resolves them needs network
/// access or a local copy of `common_types.json`.
JsonMap genUiCatalogJson(
  Catalog catalog, {
  String? title,
  String? description,
}) {
  if (catalog.catalogId == null) {
    throw ArgumentError.value(
      catalog,
      'catalog',
      'has no catalogId. Pass one to `Catalog(...)`, or set `catalog_id` in '
          'the `genui_catalog` builder options, so that a surface can name '
          'the catalog it was built against',
    );
  }
  // Copied rather than edited in place: `fullSchema` builds a fresh map on
  // every call today, but callers should not have to know that to be allowed
  // to pass a title.
  final JsonMap json = Map<String, Object?>.of(catalog.fullSchema.value);
  if (title != null) json['title'] = title;
  if (description != null) json['description'] = description;
  return json;
}

/// [genUiCatalogJson], encoded as JSON indented with [indent].
///
/// Indented because the document belongs in a repository next to the widgets
/// it describes, where it is read and reviewed like any other source file.
String genUiCatalogJsonString(
  Catalog catalog, {
  String? title,
  String? description,
  String indent = '  ',
}) => JsonEncoder.withIndent(
  indent,
).convert(genUiCatalogJson(catalog, title: title, description: description));
