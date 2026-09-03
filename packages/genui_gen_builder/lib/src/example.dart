/// Builds the few-shot example JSON for a [WidgetSpec].
///
/// One example is produced per widget. It contains the required properties
/// plus the optional ones that have an obvious sample value (enums, actions,
/// child components, `@GenUiData` objects and strings whose name hints at a
/// URL, e-mail, etc.).
library;

import 'dart:convert';

import 'spec.dart';
import 'strings.dart';

/// Returns the example as a JSON string: a list of components whose first
/// element has the id `root`.
///
/// Child components get ids prefixed with `child_` so they can never collide
/// with `root`, whatever the property is called.
String buildExampleJson(WidgetSpec spec) {
  final root = <String, Object?>{'id': 'root', 'component': spec.catalogName};
  final extra = <Map<String, Object?>>[];

  for (final prop in spec.props) {
    final sample = _sampleFor(prop, extra);
    if (sample == null) continue;
    root[prop.schemaName] = sample;
  }

  final components = [root, ...extra];
  final ids = components.map((c) => c['id']).toSet();
  assert(ids.length == components.length, 'duplicate example ids: $ids');
  return const JsonEncoder.withIndent('  ').convert(components);
}

/// Computes the sample for [prop], or `null` when the property should be
/// left out of the example. Child `Text` components are appended to [extra].
Object? _sampleFor(
  PropSpec prop,
  List<Map<String, Object?>> extra, {
  String suffix = '',
  int index = 0,
}) {
  final required = prop.isSchemaRequired;
  switch (prop.kind) {
    case PropKind.string:
      final obvious = obviousStringSample(prop.schemaName, prop.description);
      if (obvious != null) return obvious;
      return required ? 'Sample ${humanize(prop.schemaName)}$suffix' : null;
    case PropKind.integer:
    case PropKind.number:
      // Entries of a list of objects are spread apart so the example does not
      // repeat one number down a whole column. At index 0 — every widget
      // property and every standalone object — the sample is unchanged.
      return required ? 42 + index : null;
    case PropKind.decimal:
      return required ? 42.5 + index : null;
    case PropKind.boolean:
      return required ? true : null;
    case PropKind.enumeration:
      if (prop.enumValues.isEmpty) return null;
      // Entries of a list of objects walk the enum instead of repeating the
      // first value, so the example shows the model that the field varies.
      return prop.enumValues[index % prop.enumValues.length];
    case PropKind.stringList:
      return required ? ['Alpha', 'Beta'] : null;
    case PropKind.integerList:
    case PropKind.numberList:
      return required ? [1 + index, 2 + index] : null;
    case PropKind.decimalList:
      return required ? [1.5 + index, 2.5 + index] : null;
    case PropKind.enumerationList:
      if (prop.enumValues.isEmpty) return null;
      // Two values where the enum has two to give, so the example shows a
      // list rather than a single-entry one that reads like a scalar.
      return required ? prop.enumValues.take(2).toList(growable: false) : null;
    case PropKind.widget:
      final id = 'child_${prop.schemaName}';
      extra.add(_text(id, 'Sample ${humanize(prop.schemaName)}'));
      return id;
    case PropKind.widgetList:
      final ids = ['child_${prop.schemaName}_1', 'child_${prop.schemaName}_2'];
      for (var i = 0; i < ids.length; i++) {
        extra.add(
          _text(ids[i], 'Sample ${humanize(prop.schemaName)} ${i + 1}'),
        );
      }
      return ids;
    case PropKind.data:
      return buildExampleObject(prop.data!, suffix: suffix, index: index);
    case PropKind.dataList:
      return [
        for (var i = 0; i < 2; i++)
          buildExampleObject(prop.data!, suffix: ' ${i + 1}', index: i),
      ];
    case PropKind.action:
      return {
        'event': {'name': prop.eventName ?? prop.schemaName},
      };
  }
}

/// Builds one sample object for a `@GenUiData` class.
///
/// The rules match the widget example: required fields always get a value,
/// optional ones only when the sample is obvious (enums, nested objects,
/// strings whose name hints at a format). [suffix] distinguishes the entries
/// of a list of objects (`Sample label 1`, `Sample label 2`) and [index] is
/// the 0-based position of the entry, which rotates enum samples and spreads
/// numeric ones.
Map<String, Object?> buildExampleObject(
  DataSpec spec, {
  String suffix = '',
  int index = 0,
}) {
  final object = <String, Object?>{};
  for (final field in spec.fields) {
    final sample = _sampleFor(field, const [], suffix: suffix, index: index);
    if (sample == null) continue;
    object[field.schemaName] = sample;
  }
  return object;
}

Map<String, Object?> _text(String id, String text) => {
  'id': id,
  'component': 'Text',
  'text': text,
};

/// Returns a realistic sample for string properties whose name or description
/// makes the expected format obvious, otherwise `null`.
String? obviousStringSample(String name, String? description) {
  final hint = '${name.toLowerCase()} ${(description ?? '').toLowerCase()}';
  bool has(List<String> words) => words.any(hint.contains);

  if (has(['image', 'photo', 'avatar', 'thumbnail', 'picture'])) {
    // A real, stable placeholder so development tooling such as
    // DebugCatalogView renders an actual picture instead of a broken image.
    return 'https://picsum.photos/seed/genui_gen/400/225';
  }
  if (has(['url', 'uri', 'href', 'link'])) {
    return 'https://example.com';
  }
  if (has(['email', 'e-mail'])) return 'user@example.com';
  if (has(['phone'])) return '+1 555 0100';
  if (has(['date'])) return '2026-01-15';
  if (has(['color', 'colour'])) return '#3366FF';
  return null;
}
