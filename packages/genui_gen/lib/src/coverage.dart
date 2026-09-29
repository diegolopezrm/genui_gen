import 'package:genui/genui.dart';

import 'audit.dart';
import 'catalog_json.dart';
import 'tracing/trace.dart';

/// What a corpus of recorded sessions says the agent actually used.
///
/// A catalog is paid for in every request, whether the agent composes with it
/// or not. `genUiCatalogWeight` says what each component costs; this says
/// which ones earned it. The two together answer the question nothing else
/// does: is this catalog too big, and which part of it is the dead weight.
class GenUiCoverage {
  /// Creates a [GenUiCoverage].
  const GenUiCoverage({
    required this.sessions,
    required this.surfaces,
    required this.componentUses,
    required this.propertyUses,
    required this.enumValueUses,
    required this.catalogComponents,
    required this.catalogProperties,
    required this.catalogEnumValues,
    required this.weight,
  });

  /// How many traces were read.
  final int sessions;

  /// How many surfaces those traces composed.
  final int surfaces;

  /// How many times each component was composed, largest first.
  final Map<String, int> componentUses;

  /// Which properties of each component the agent ever filled.
  final Map<String, Set<String>> propertyUses;

  /// Which values of each enum property the agent ever chose.
  ///
  /// Keyed `Component.property`.
  final Map<String, Set<String>> enumValueUses;

  /// Every component the catalog offers.
  final Set<String> catalogComponents;

  /// Every property each component offers.
  final Map<String, Set<String>> catalogProperties;

  /// Every value each enum property offers, keyed `Component.property`.
  final Map<String, Set<String>> catalogEnumValues;

  /// What the catalog costs, when one was measured.
  final GenUiCatalogWeight? weight;

  /// Components the agent never composed.
  Set<String> get unusedComponents =>
      catalogComponents.difference(componentUses.keys.toSet());

  /// Properties the agent never filled, for components it did compose.
  ///
  /// A component it never composed is reported whole rather than property by
  /// property, which would say the same thing many times over.
  Map<String, Set<String>> get unusedProperties => <String, Set<String>>{
    for (final entry in catalogProperties.entries)
      if (componentUses.containsKey(entry.key))
        if (entry.value
            .difference(propertyUses[entry.key] ?? const <String>{})
            .isNotEmpty)
          entry.key: entry.value.difference(
            propertyUses[entry.key] ?? const <String>{},
          ),
  };

  /// Enum values the agent never chose, for properties it did fill.
  Map<String, Set<String>> get unusedEnumValues => <String, Set<String>>{
    for (final entry in catalogEnumValues.entries)
      if (enumValueUses.containsKey(entry.key))
        if (entry.value.difference(enumValueUses[entry.key]!).isNotEmpty)
          entry.key: entry.value.difference(enumValueUses[entry.key]!),
  };

  /// The share of the catalog's components the agent composed, 0 to 1.
  double get componentShare => catalogComponents.isEmpty
      ? 1
      : componentUses.keys.length / catalogComponents.length;

  /// What the components the agent never composed cost, in characters.
  ///
  /// Null when no catalog document was measured.
  int? get wastedCharacters {
    final GenUiCatalogWeight? w = weight;
    if (w == null) return null;
    var total = 0;
    for (final String name in unusedComponents) {
      total += w.byComponent[name] ?? 0;
    }
    return total;
  }

  /// A report for a test that prints it or a CI job that keeps it in the log.
  String describe() {
    final buffer = StringBuffer()
      ..writeln(
        '${componentUses.keys.length} of ${catalogComponents.length} '
        'components used across $sessions '
        'session${sessions == 1 ? '' : 's'} and $surfaces '
        'surface${surfaces == 1 ? '' : 's'}',
      );

    final unused = unusedComponents.toList()..sort();
    if (unused.isNotEmpty) {
      final GenUiCatalogWeight? w = weight;
      buffer.writeln('  never composed:');
      for (final String name in unused) {
        final int? cost = w?.byComponent[name];
        buffer.writeln(
          cost == null
              ? '    $name'
              : '    ${cost.toString().padLeft(6)}  '
                    '${(w!.shareOf(name) * 100).toStringAsFixed(1)}%  $name',
        );
      }
      final int? wasted = wastedCharacters;
      if (wasted != null && w != null && w.total > 0) {
        buffer.writeln(
          '    ${wasted.toString().padLeft(6)}  '
          '${(wasted / w.total * 100).toStringAsFixed(1)}%  in every request, '
          'for components the agent never asked for',
        );
      }
    }

    final unusedProps = unusedProperties;
    if (unusedProps.isNotEmpty) {
      buffer.writeln('  composed, with properties never filled:');
      final names = unusedProps.keys.toList()..sort();
      for (final String name in names) {
        final props = unusedProps[name]!.toList()..sort();
        buffer.writeln('    $name: ${props.join(', ')}');
      }
    }

    final unusedEnums = unusedEnumValues;
    if (unusedEnums.isNotEmpty) {
      buffer.writeln('  enum values never chosen:');
      final keys = unusedEnums.keys.toList()..sort();
      for (final String key in keys) {
        final values = unusedEnums[key]!.toList()..sort();
        buffer.writeln('    $key: ${values.join(', ')}');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => describe();
}

/// Reads [traces] and reports what the agent did with [catalog].
///
/// Every component the agent composed is counted, along with the properties
/// it filled and the enum values it chose. What is left over is the part of
/// the catalog that travels in every request and has never been used.
///
/// ```dart
/// final coverage = genUiCoverage(catalog: genUiCatalog, traces: recorded);
/// print(coverage.describe());
/// expect(coverage.unusedComponents, isEmpty,
///     reason: 'the prompt is paying for components nobody composes');
/// ```
///
/// A component being unused is not automatically wrong: a catalog is written
/// before the conversations that use it, and an error state should be rare.
/// It is a number to look at, not a rule to enforce, which is why this hands
/// back the counts rather than a verdict.
GenUiCoverage genUiCoverage({
  required Catalog catalog,
  required Iterable<GenUiTrace> traces,
}) {
  final componentUses = <String, int>{};
  final propertyUses = <String, Set<String>>{};
  final enumValueUses = <String, Set<String>>{};
  final surfaces = <String>{};

  var sessions = 0;
  for (final GenUiTrace trace in traces) {
    sessions++;
    for (final GenUiTraceStep step in trace.steps) {
      if (step is! GenUiMessageStep) continue;
      final Object? update = step.message['updateComponents'];
      if (update is! Map) continue;
      final Object? surfaceId = update['surfaceId'];
      if (surfaceId is String) surfaces.add('$sessions/$surfaceId');
      final Object? components = update['components'];
      if (components is! List) continue;
      for (final Object? component in components) {
        if (component is! Map) continue;
        final Object? name = component['component'];
        if (name is! String) continue;
        componentUses[name] = (componentUses[name] ?? 0) + 1;
        final props = propertyUses.putIfAbsent(name, () => <String>{});
        for (final Object? key in component.keys) {
          if (key is! String || key == 'id' || key == 'component') continue;
          props.add(key);
          final Object? value = component[key];
          if (value is String) {
            enumValueUses
                .putIfAbsent('$name.$key', () => <String>{})
                .add(value);
          }
        }
      }
    }
  }

  final sorted = componentUses.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final catalogProperties = <String, Set<String>>{};
  final catalogEnumValues = <String, Set<String>>{};
  for (final CatalogItem item in catalog.items) {
    final Object schema = item.dataSchema.value;
    if (schema is! Map) continue;
    final Object? properties = schema['properties'];
    if (properties is! Map) continue;
    final names = <String>{
      for (final Object? key in properties.keys)
        if (key is String && key != 'component') key,
    };
    catalogProperties[item.name] = names;
    for (final String name in names) {
      final Set<String> values = _enumValuesIn(properties[name]);
      if (values.isNotEmpty) {
        catalogEnumValues['${item.name}.$name'] = values;
      }
    }
  }

  GenUiCatalogWeight? weight;
  if (catalog.catalogId != null) {
    weight = genUiCatalogWeight(genUiCatalogJson(catalog));
  }

  return GenUiCoverage(
    sessions: sessions,
    surfaces: surfaces.length,
    componentUses: <String, int>{for (final e in sorted) e.key: e.value},
    propertyUses: propertyUses,
    enumValueUses: enumValueUses,
    catalogComponents: catalog.items.map((i) => i.name).toSet(),
    catalogProperties: catalogProperties,
    catalogEnumValues: catalogEnumValues,
    weight: weight,
  );
}

/// The enum values declared anywhere inside a property's schema.
///
/// A generated enum property is a `DynamicString` combined with an `anyOf`
/// holding the constants, so the list is not at a fixed depth. Searching for
/// it costs nothing and survives the shape changing.
Set<String> _enumValuesIn(Object? schema) {
  final found = <String>{};
  void walk(Object? node) {
    if (node is List) {
      for (final Object? child in node) {
        walk(child);
      }
      return;
    }
    if (node is! Map) return;
    final Object? values = node['enum'];
    if (values is List) {
      for (final Object? v in values) {
        if (v is String) found.add(v);
      }
    }
    for (final Object? child in node.values) {
      walk(child);
    }
  }

  walk(schema);
  return found;
}
