/// Verifies that the identifiers used by generated code resolve in the
/// annotated library.
///
/// The generated file is a `part of` the annotated library and therefore has
/// no imports of its own. Rather than emitting code that fails to compile,
/// the generator checks the library scope up front and tells the user which
/// import lines to add.
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

const _genui = "import 'package:genui/genui.dart';";
const _genuiGen = "import 'package:genui_gen/genui_gen.dart';";
const _jsonSchemaBuilder =
    "import 'package:json_schema_builder/json_schema_builder.dart';";
const _flutter = "import 'package:flutter/widgets.dart';";

/// Which import provides each identifier the emitter may reference.
const importForSymbol = <String, String>{
  'CatalogItem': _genui,
  'A2uiSchemas': _genui,
  'JsonMap': _genui,
  'S': _jsonSchemaBuilder,
  'ObjectSchema': _jsonSchemaBuilder,
  'GenUiBindings': _genuiGen,
  'GenUiBinding': _genuiGen,
  'GenUiMissingFieldReporter': _genuiGen,
  'genUiActionHandler': _genuiGen,
  'genUiReportMissing': _genuiGen,
  'genUiAsString': _genuiGen,
  'genUiAsNum': _genuiGen,
  'genUiAsBool': _genuiGen,
  'genUiAsStringList': _genuiGen,
  'genUiAsNumList': _genuiGen,
  'genUiAsObject': _genuiGen,
  'genUiAsObjectList': _genuiGen,
  'genUiMissingField': _genuiGen,
  'genUiNestedField': _genuiGen,
  'SizedBox': _flutter,
  'Widget': _flutter,
};

/// Throws [InvalidGenerationSourceError] listing the missing imports when any
/// of [symbols] does not resolve in [library].
void checkImports(
  LibraryElement library,
  Iterable<String> symbols,
  Element element,
) {
  final scope = library.firstFragment.scope;
  final wanted = symbols.toSet();
  for (final symbol in wanted) {
    if (!importForSymbol.containsKey(symbol)) {
      throw StateError('No import known for generated symbol `$symbol`.');
    }
  }
  // Iterate the table rather than [symbols] so the message order is stable.
  final missingByImport = <String, List<String>>{};
  for (final entry in importForSymbol.entries) {
    final symbol = entry.key;
    if (!wanted.contains(symbol)) continue;
    if (scope.lookup(symbol).getter != null) continue;
    missingByImport.putIfAbsent(entry.value, () => []).add(symbol);
  }
  if (missingByImport.isEmpty) return;

  final lines = [
    for (final entry in missingByImport.entries)
      '  ${entry.key}    // provides ${entry.value.join(', ')}',
  ]..sort();
  final prefixed = [
    for (final import in missingByImport.keys)
      for (final prefix in _prefixesFor(library, import))
        '`${_uriOf(import)}` is imported with prefix `$prefix`, but generated '
            'code needs its identifiers unprefixed',
  ];
  final prefixNote = prefixed.isEmpty
      ? ''
      : '\n${prefixed.join('\n')}. Add an unprefixed import next to it '
            '(a `show` list is fine).';
  throw InvalidGenerationSourceError(
    'The generated code for `${element.displayName}` references identifiers '
    'that are not in scope in ${library.uri}. Generated files are '
    'parts of the annotated library, so add the following import(s) to it:\n'
    '${lines.join('\n')}$prefixNote',
    element: element,
  );
}

/// The URI inside an `import '...';` line.
String _uriOf(String importLine) => importLine.substring(
  importLine.indexOf("'") + 1,
  importLine.lastIndexOf("'"),
);

/// Prefixes under which [library] already imports the URI of [importLine].
Iterable<String> _prefixesFor(LibraryElement library, String importLine) sync* {
  final uri = _uriOf(importLine);
  for (final fragment in library.fragments) {
    for (final import in fragment.libraryImports) {
      final prefix = import.prefix?.name;
      if (prefix == null) continue;
      if (import.importedLibrary?.uri.toString() == uri) yield prefix;
    }
  }
}
