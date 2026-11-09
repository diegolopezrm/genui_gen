import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

/// The A2UI catalog document that describes [catalog].
///
/// A catalog is the contract between the agent and the app: it says which
/// components exist and what each one accepts. An agent that prompts a model
/// in Dart builds that description in memory, but everything outside this
/// Flutter process needs it as a document — an agent written in Python, a
/// second client rendering the same surfaces in SwiftUI, a review that has to
/// answer what the model was allowed to ask for last Tuesday.
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
/// [title] and [description] set the document's own `title` and
/// `description`, which a catalog defined in code does not have. An agent that
/// is handed three of these has nothing else to tell them apart by.
///
/// The `$ref`s in the result point at the shared types in A2UI's
/// `common_types.json` for the catalog's protocol version, so whatever
/// resolves them needs a copy of that file.
Map<String, Object?> genUiCatalogJson(
  CatalogApi catalog, {
  String? title,
  String? description,
}) {
  // `toJson` hands back a fresh copy, so setting a title here leaves the
  // catalog as it was.
  final Map<String, Object?> json = catalog.toJson();
  if (title != null) json['title'] = title;
  if (description != null) json['description'] = description;
  return json;
}

/// [genUiCatalogJson], encoded as JSON indented with [indent].
///
/// Indented because the document belongs in a repository next to the widgets
/// it describes, where it is read and reviewed like any other source file.
String genUiCatalogJsonString(
  CatalogApi catalog, {
  String? title,
  String? description,
  String indent = '  ',
}) => JsonEncoder.withIndent(
  indent,
).convert(genUiCatalogJson(catalog, title: title, description: description));
