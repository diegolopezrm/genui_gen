/// Builds the few-shot example JSON for a [WidgetSpec].
///
/// One example is produced per widget. It contains the required properties
/// plus the optional ones that have an obvious sample value (enums, actions,
/// child components and strings whose name hints at a URL, e-mail, etc.).
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
Object? _sampleFor(PropSpec prop, List<Map<String, Object?>> extra) {
  final required = prop.isSchemaRequired;
  switch (prop.kind) {
    case PropKind.string:
      final obvious = obviousStringSample(prop.schemaName, prop.description);
      if (obvious != null) return obvious;
      return required ? 'Sample ${humanize(prop.schemaName)}' : null;
    case PropKind.integer:
    case PropKind.number:
      return required ? 42 : null;
    case PropKind.decimal:
      return required ? 42.5 : null;
    case PropKind.boolean:
      return required ? true : null;
    case PropKind.enumeration:
      return prop.enumValues.isEmpty ? null : prop.enumValues.first;
    case PropKind.stringList:
      return required ? ['Alpha', 'Beta'] : null;
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
    case PropKind.action:
      return {
        'event': {'name': prop.eventName ?? prop.schemaName},
      };
  }
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
    return 'https://example.com/sample.png';
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
