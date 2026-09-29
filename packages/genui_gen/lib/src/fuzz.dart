import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// How the caller puts a widget on screen.
///
/// In a widget test this is `tester.pumpWidget`. Taken as a callback rather
/// than by importing `flutter_test` here, because this package sits in an
/// app's `dependencies` and the test harness has no business shipping with
/// it.
typedef GenUiPump = Future<void> Function(Widget widget);

/// Why a case is being reported.
enum GenUiFuzzKind {
  /// An exception escaped while the component was building.
  ///
  /// This is the one that matters. A model composes against the schema, not
  /// against what the widget happens to tolerate, so anything the schema
  /// allows will eventually arrive.
  threw,

  /// The component built, but took up no space at all.
  ///
  /// Only reported when the untouched example did take up space, so the
  /// mutation is what emptied it. A component that renders nothing is not a
  /// crash, but it is a blank area where the agent asked for something, and
  /// nobody finds out until a user does.
  renderedNothing,
}

/// One thing a fuzz run found.
class GenUiFuzzFinding {
  /// Creates a [GenUiFuzzFinding].
  const GenUiFuzzFinding({
    required this.component,
    required this.mutation,
    required this.kind,
    required this.detail,
    required this.componentJson,
  });

  /// The catalog component that was rendered.
  final String component;

  /// What was done to the example to produce this case.
  final String mutation;

  /// What went wrong.
  final GenUiFuzzKind kind;

  /// The exception, or a note about what was rendered.
  final String detail;

  /// The exact component the renderer was handed.
  ///
  /// Printed so the case can be pasted straight into a test rather than
  /// reconstructed from a description of it.
  final String componentJson;

  @override
  String toString() {
    final String json = componentJson.length > 240
        ? '${componentJson.substring(0, 240)}…'
        : componentJson;
    return '$component: $mutation\n'
        '  ${kind.name}: $detail\n'
        '  $json';
  }
}

/// A table of [findings], one line per component, for a CI log.
///
/// The detail is in the findings themselves; this is what to look at first
/// when a run comes back with sixty of them and the question is which
/// component to open.
String genUiFuzzSummary(List<GenUiFuzzFinding> findings) {
  if (findings.isEmpty) return 'nothing broke';
  final byComponent = <String, List<GenUiFuzzFinding>>{};
  for (final f in findings) {
    byComponent.putIfAbsent(f.component, () => <GenUiFuzzFinding>[]).add(f);
  }
  final names = byComponent.keys.toList()
    ..sort((a, b) => byComponent[b]!.length.compareTo(byComponent[a]!.length));
  final buffer = StringBuffer(
    '${findings.length} in ${names.length} '
    'component${names.length == 1 ? '' : 's'}\n',
  );
  for (final String name in names) {
    final List<GenUiFuzzFinding> mine = byComponent[name]!;
    final int threw = mine.where((f) => f.kind == GenUiFuzzKind.threw).length;
    final int empty = mine.length - threw;
    buffer.writeln(
      '  ${mine.length.toString().padLeft(4)}  $name'
      '${threw > 0 ? '  ($threw threw' : '  ('}'
      '${empty > 0 ? '${threw > 0 ? ', ' : ''}$empty rendered nothing' : ''})',
    );
  }
  return buffer.toString();
}

/// Renders everything [catalog]'s own examples allow, mutated, and reports
/// what broke.
///
/// A catalog is a contract with something that cannot be recompiled, and the
/// only thing holding a model to it is a JSON schema. Every widget test writes
/// the input the author had in mind; this writes the inputs the schema permits
/// and the author did not. A required property the model left out, a string
/// where a number was declared, a binding that never resolves, a list with two
/// hundred entries: each of those is a message a real agent can send, and each
/// one renders here before it renders in front of someone.
///
/// The cases are built by mutating each item's own generated example rather
/// than by reading the schema, because the example is valid by construction
/// and already names every required property. That also means a hand-written
/// `CatalogItem` is fuzzed as well as a generated one, as long as it carries
/// example data.
///
/// ```dart
/// testWidgets('the catalog survives what its schema allows', (tester) async {
///   final findings = await genUiFuzz(
///     catalog: exampleCatalog,
///     pump: tester.pumpWidget,
///   );
///   expect(findings, isEmpty, reason: findings.join('\n\n'));
/// });
/// ```
///
/// [reportEmpty] also reports a case that rendered nothing at all. It is off
/// by default because most of those are correct: take the items away from a
/// list and it has nothing to draw. Turn it on when you want to find the
/// component that swallows a wrong-typed property and leaves a blank space
/// where the agent asked for something.
///
/// [skip] leaves components out by name, for the ones whose failure you have
/// already accepted. [only] restricts the run to a few while you are fixing
/// one. [maxCasesPerComponent] bounds a component with many properties; the
/// cases are generated in a fixed order, so a run is reproducible and a bound
/// always drops the same tail.
Future<List<GenUiFuzzFinding>> genUiFuzz({
  required Catalog catalog,
  required GenUiPump pump,
  Set<String> only = const <String>{},
  Set<String> skip = const <String>{},
  int maxCasesPerComponent = 80,
  bool reportEmpty = false,
}) async {
  final String? catalogId = catalog.catalogId;
  if (catalogId == null) {
    throw ArgumentError.value(
      catalog,
      'catalog',
      'has no catalogId, and a surface names the catalog it was built '
          'against. Give the catalog an id before fuzzing it.',
    );
  }

  final findings = <GenUiFuzzFinding>[];
  var surface = 0;

  for (final CatalogItem item in catalog.items) {
    if (skip.contains(item.name)) continue;
    if (only.isNotEmpty && !only.contains(item.name)) continue;

    final List<JsonMap>? example = _parseExample(item);
    if (example == null) continue;

    final int rootIndex = example.indexWhere((c) => c['id'] == 'root');
    final JsonMap root = example[rootIndex < 0 ? 0 : rootIndex];
    final int index = rootIndex < 0 ? 0 : rootIndex;

    // The untouched example first: it is the baseline every case is compared
    // against, and a component whose own example throws needs no fuzzing to
    // be worth reporting.
    final _Render baseline = await _render(
      pump,
      catalog,
      catalogId,
      example,
      's${surface++}',
    );
    if (baseline.error != null) {
      findings.add(
        GenUiFuzzFinding(
          component: item.name,
          mutation: 'its own generated example',
          kind: GenUiFuzzKind.threw,
          detail: baseline.error!,
          componentJson: jsonEncode(root),
        ),
      );
      continue;
    }

    for (final _Case c in _casesFor(root).take(maxCasesPerComponent)) {
      final List<JsonMap> components = <JsonMap>[...example];
      components[index] = c.component;

      final _Render r = await _render(
        pump,
        catalog,
        catalogId,
        components,
        's${surface++}',
      );
      if (r.error != null) {
        findings.add(
          GenUiFuzzFinding(
            component: item.name,
            mutation: c.label,
            kind: GenUiFuzzKind.threw,
            detail: r.error!,
            componentJson: jsonEncode(c.component),
          ),
        );
      } else if (reportEmpty && baseline.hasSize && !r.hasSize) {
        findings.add(
          GenUiFuzzFinding(
            component: item.name,
            mutation: c.label,
            kind: GenUiFuzzKind.renderedNothing,
            detail: 'the untouched example took up space and this took up none',
            componentJson: jsonEncode(c.component),
          ),
        );
      }
    }
  }

  return findings;
}

/// One case: a mutated component and the sentence describing what was done.
class _Case {
  const _Case(this.label, this.component);

  final String label;
  final JsonMap component;
}

/// What one render produced.
class _Render {
  const _Render(this.error, this.hasSize);

  final String? error;
  final bool hasSize;
}

/// The cases for one component, in a fixed order.
///
/// Every value here is something the schema permits or a model can produce:
/// a property left out, a null, the wrong scalar, an empty or enormous list,
/// a binding that resolves to nothing, a string longer than any layout
/// expects. None of them is exotic; all of them arrive eventually.
Iterable<_Case> _casesFor(JsonMap root) sync* {
  final keys = root.keys.where((k) => k != 'id' && k != 'component').toList()
    ..sort();

  // Nothing but the identity: every optional property gone at once, which is
  // what a terse model produces.
  yield _Case('only id and component', <String, Object?>{
    'id': root['id'],
    'component': root['component'],
  });

  for (final String key in keys) {
    yield _Case('without `$key`', _without(root, key));
    for (final _Value v in _values) {
      yield _Case('`$key` as ${v.label}', _with(root, key, v.value));
    }
  }
}

/// A value to put in a property, and what to call it in a report.
class _Value {
  const _Value(this.label, this.value);

  final String label;
  final Object? value;
}

final List<_Value> _values = <_Value>[
  const _Value('null', null),
  const _Value('an empty string', ''),
  const _Value('a string', 'genui_fuzz'),
  const _Value('a number', 42),
  const _Value('a negative number', -1),
  const _Value('a boolean', true),
  const _Value('an empty list', <Object?>[]),
  const _Value('an empty object', <String, Object?>{}),
  _Value('an unresolved binding', const {'path': '/genui_fuzz/nothing_here'}),
  _Value('a call to a function nobody registered', const {
    'call': 'genUiFuzzNoSuchFunction',
    'args': <String, Object?>{},
  }),
  _Value('a very long string', 'x' * 5000),
  _Value('a list of 200 strings', List<Object?>.filled(200, 'genui_fuzz')),
  _Value(
    'a list of 200 objects',
    List<Object?>.filled(200, const {'label': 'genui_fuzz', 'value': 1}),
  ),
  const _Value('a list holding a null', <Object?>[null]),
  const _Value('a list of the wrong element type', <Object?>[1, 'two', true]),
];

JsonMap _without(JsonMap root, String key) => <String, Object?>{
  for (final e in root.entries)
    if (e.key != key) e.key: e.value,
};

JsonMap _with(JsonMap root, String key, Object? value) => <String, Object?>{
  ...root,
  key: value,
};

/// Parses the first example an item carries, or `null` when it has none that
/// can be read as a list of components.
List<JsonMap>? _parseExample(CatalogItem item) {
  for (final String Function() example in item.exampleData) {
    try {
      final Object? decoded = jsonDecode(example());
      if (decoded is List && decoded.isNotEmpty) {
        return <JsonMap>[
          for (final Object? c in decoded)
            if (c is Map) c.cast<String, Object?>(),
        ];
      }
    } on FormatException {
      continue;
    }
    continue;
  }
  return null;
}

/// Renders [components] on a fresh surface and reports what happened.
Future<_Render> _render(
  GenUiPump pump,
  Catalog catalog,
  String catalogId,
  List<JsonMap> components,
  String surfaceId,
) async {
  final controller = SurfaceController(catalogs: [catalog]);
  final probe = GlobalKey();
  final errors = <Object>[];

  // The case is the error, so it is collected rather than allowed to reach
  // the test binding, which would fail the run on the first component that
  // misbehaves instead of reporting all of them.
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) =>
      errors.add(details.exception);

  Size? size;
  try {
    controller.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: components,
      ),
    );
    controller.handleMessage(
      core.CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
    );
    await pump(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KeyedSubtree(
              key: probe,
              child: Surface(surfaceContext: controller.contextFor(surfaceId)),
            ),
          ),
        ),
      ),
    );
    size = probe.currentContext?.size;
  } catch (error) {
    errors.add(error);
  }

  // Unmount before disposing, so a widget still on screen cannot reach a
  // controller that is going away and report that instead of the real case.
  try {
    await pump(const SizedBox.shrink());
  } catch (error) {
    errors.add(error);
  }
  FlutterError.onError = previous;
  controller.dispose();

  return _Render(
    errors.isEmpty ? null : _describe(errors.first),
    size != null && size.width > 0 && size.height > 0,
  );
}

/// The first line of an error, which is the part that identifies it.
String _describe(Object error) {
  final String text = error is FlutterError ? error.message : error.toString();
  final int newline = text.indexOf('\n');
  final String first = newline < 0 ? text : text.substring(0, newline);
  return first.length > 300 ? '${first.substring(0, 300)}…' : first;
}
