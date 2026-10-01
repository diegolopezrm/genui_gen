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
      final format = obviousStringSample(prop.schemaName, prop.description);
      if (format != null) return format;
      if (!required) return null;
      final prose = proseStringSample(prop.schemaName, index: index);
      return prose ?? 'Sample ${humanize(prop.schemaName)}$suffix';
    case PropKind.integer:
    case PropKind.number:
      final obvious = required
          ? obviousNumberSample(prop.schemaName, prop.description, index: index)
          : null;
      if (obvious != null) return obvious is int ? obvious : obvious.round();
      // Entries of a list of objects are spread apart so the example does not
      // repeat one number down a whole column. At index 0 — every widget
      // property and every standalone object — the sample is unchanged.
      return required ? 42 + index : null;
    case PropKind.decimal:
      final obviousDecimal = required
          ? obviousNumberSample(prop.schemaName, prop.description, index: index)
          : null;
      if (obviousDecimal != null) return obviousDecimal.toDouble();
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
    case PropKind.map:
      if (!required) return null;
      return switch (prop.mapValueKind) {
        PropKind.boolean => {'alpha': true, 'beta': false},
        PropKind.string => {'alpha': 'Sample alpha', 'beta': 'Sample beta'},
        PropKind.enumeration when prop.enumValues.isNotEmpty => {
          'alpha': prop.enumValues.first,
          'beta': prop.enumValues.last,
        },
        null => {'alpha': 'Sample alpha', 'beta': 2},
        _ => {'alpha': 1, 'beta': 2},
      };
    case PropKind.valueWriter:
    case PropKind.checkResult:
      // Derived from the property it writes to, and never sent by the model.
      return null;
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
  if (has(['time'])) return '14:30';
  if (has(['color', 'colour'])) return '#3366FF';
  if (has(['currency'])) return 'USD';
  if (has(['sku', 'barcode', 'reference code'])) return 'SKU-4821';
  return null;
}

/// A line of copy that reads like the thing the property is called.
///
/// Only used for a property the example would have carried anyway, with the
/// placeholder `Sample title` in it. A sample is a lesson: leave `42` in a
/// price and the model learns that prices are round integers. These cost the
/// same and teach something true.
///
/// Kept apart from [obviousStringSample] on purpose. That one is about
/// *format* — a URL, a date, a hex colour — and is worth showing even for an
/// optional property, because the model cannot guess the shape. This one is
/// about prose, and putting prose in the example for a property nobody asked
/// for teaches the model to fill it in.
String? proseStringSample(String name, {int index = 0}) {
  // The name only, not the description. A field called `label` whose comment
  // reads "a short caption naming the metric" is not a caption, and matching
  // prose against prose finds that sort of thing constantly. Format hints can
  // afford to read the description because a URL is a URL wherever it is
  // mentioned; a title is not.
  final hint = name.toLowerCase();
  bool has(List<String> words) => words.any(hint.contains);
  String pick(List<String> options) => options[index % options.length];

  if (has(['country'])) return pick(['Colombia', 'Spain', 'Chile']);
  if (has(['city', 'town'])) {
    return pick(['Bucaramanga', 'Valencia', 'Santiago']);
  }
  if (has(['address', 'street'])) {
    return pick(['4th Street 21-30', '18th Avenue 5-12']);
  }
  if (has(['author', 'owner', 'username', 'full name'])) {
    return pick(['Ada Lovelace', 'Grace Hopper', 'Alan Turing']);
  }
  if (has(['first name'])) return pick(['Ada', 'Grace', 'Alan']);
  if (has(['last name', 'surname'])) {
    return pick(['Lovelace', 'Hopper', 'Turing']);
  }
  if (has(['title', 'heading', 'headline'])) {
    return pick(['Quarterly report', 'Monthly summary', 'Weekly digest']);
  }
  if (has(['subtitle', 'caption'])) {
    return pick([
      'Updated this morning',
      'Updated yesterday',
      'Updated last week',
    ]);
  }
  if (has(['description', 'summary', 'body'])) {
    return pick([
      'A short line of copy, the length a real one tends to be.',
      'Another line, so the model sees they differ.',
    ]);
  }
  if (has(['message', 'error'])) {
    return pick([
      'Something needs your attention.',
      'That did not go through.',
    ]);
  }
  if (has(['placeholder', 'hint'])) return pick(['Start typing', 'Search']);
  if (has(['search', 'query'])) {
    return pick(['noise cancelling headphones', 'running shoes']);
  }
  if (has(['status'])) return pick(['active', 'paused', 'archived']);
  return null;
}

/// A number that reads like the thing the property is called, or `null` when
/// the name says nothing.
///
/// The sample is what the model learns the property is for. `42` in a price
/// teaches it that prices are round integers, and it will produce them. A
/// number that looks like a real one of its kind costs the same and teaches
/// the opposite.
///
/// [index] spreads the entries of a list apart, so an example table does not
/// repeat one value down a column.
num? obviousNumberSample(String name, String? description, {int index = 0}) {
  final hint = '${name.toLowerCase()} ${(description ?? '').toLowerCase()}';
  bool has(List<String> words) => words.any(hint.contains);

  if (has(['percent', 'progress', 'ratio', 'share'])) {
    return <num>[0.65, 0.4, 0.85][index % 3];
  }
  if (has(['price', 'amount', 'cost', 'total', 'subtotal', 'balance'])) {
    return <num>[19.99, 249.5, 7.25][index % 3];
  }
  if (has(['rating', 'score', 'stars'])) return <num>[4.5, 3.8, 4.9][index % 3];
  if (has(['year'])) return 2026;
  if (has(['month'])) return 1 + index % 12;
  if (has(['day'])) return 1 + index % 28;
  if (has(['age'])) return <num>[34, 41, 27][index % 3];
  if (has(['count', 'quantity', 'items', 'number of'])) {
    return <num>[3, 12, 1][index % 3];
  }
  if (has(['duration', 'seconds', 'minutes', 'elapsed'])) {
    return <num>[30, 90, 15][index % 3];
  }
  if (has(['width', 'height', 'size', 'radius', 'spacing', 'padding'])) {
    return <num>[120, 64, 16][index % 3];
  }
  if (has(['latitude'])) return 7.1193;
  if (has(['longitude'])) return -73.1227;
  if (has(['weight'])) return <num>[1.2, 0.8, 2.5][index % 3];
  if (has(['temperature'])) return <num>[22.5, 18, 31][index % 3];
  return null;
}
