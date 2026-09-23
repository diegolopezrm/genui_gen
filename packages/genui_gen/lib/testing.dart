/// Test helpers for the catalog the generator produced.
///
/// A generated `CatalogItem` is a contract with a model: these components
/// exist, they take these properties, and this is what the app does with them.
/// The schema half of that contract is checked at build time. This library
/// checks the other half — what the rendered component exposes to the person
/// using it — by recording the semantics of each item's example and failing
/// when they change.
///
/// The recorded file is the same shape A2UI's rendering cases are written in,
/// so it doubles as the answer to "what can the model make this app announce",
/// which is not visible from a Dart diff.
///
/// ```dart
/// // test/genui_semantics_test.dart
/// import 'dart:io';
///
/// import 'package:flutter/material.dart';
/// import 'package:flutter_test/flutter_test.dart';
/// import 'package:genui_gen/testing.dart';
/// import 'package:my_app/genui_catalog.g.dart';
///
/// void main() {
///   testWidgets('the catalog exposes what it did before', (tester) async {
///     final recorded = <String, List<GenUiSemanticNode>>{};
///     for (final item in genUiCatalog.items) {
///       final handle = tester.ensureSemantics();
///       await tester.pumpWidget(
///         MaterialApp(
///           home: Scaffold(
///             body: GenUiExampleSurface(catalog: genUiCatalog, item: item),
///           ),
///         ),
///       );
///       await tester.pumpAndSettle();
///       recorded[item.name] = genUiRenderedSemantics();
///       handle.dispose();
///     }
///
///     expect(
///       genUiSemanticsGolden(recorded, File('test/genui_semantics.json')),
///       isNull,
///     );
///   });
/// }
/// ```
///
/// [genUiSemanticsAudit] reads the same recording and reports what a person
/// using a screen reader could not work with: a control with no name, a
/// component that reaches assistive technology as nothing at all, two buttons
/// that announce themselves identically. [genUiCatalogWeight] answers a
/// different question with the same catalog: how much of every prompt each
/// component takes up.
///
/// [genUiCatalogDiff] answers the other half of the question, about the
/// contract rather than the rendering: what changed for the model between two
/// versions of the catalog, and whether a message composed against the old one
/// can still be wrong.
///
/// Record the file the first time, and after a deliberate change, by setting
/// `GENUI_UPDATE_GOLDENS=1`:
///
/// ```sh
/// GENUI_UPDATE_GOLDENS=1 flutter test test/genui_semantics_test.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'src/semantics.dart';

export 'src/audit.dart';
export 'src/catalog_diff.dart';
export 'src/example_surface.dart';
export 'src/semantics.dart';

/// Compares [recorded] against [golden], and returns what differs, or `null`
/// when nothing does.
///
/// Writes [golden] instead of comparing when the file does not exist yet, or
/// when `GENUI_UPDATE_GOLDENS` is set in the environment. Recording is
/// deliberately not the default: a file that rewrites itself on every run
/// cannot fail, and the point is to fail when a component stops exposing what
/// it used to.
String? genUiSemanticsGolden(
  Map<String, List<GenUiSemanticNode>> recorded,
  File golden, {
  bool? update,
}) {
  final bool write = update ?? (!golden.existsSync() || _updateRequested());
  if (write) {
    golden
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${_encode(recorded)}\n');
    return null;
  }

  final Map<String, List<GenUiSemanticNode>> expected = _decode(
    golden.readAsStringSync(),
  );

  final out = StringBuffer();
  for (final name in <String>{
    ...expected.keys,
    ...recorded.keys,
  }.toList()..sort()) {
    final List<GenUiSemanticNode>? want = expected[name];
    final List<GenUiSemanticNode>? got = recorded[name];
    if (want == null) {
      out.writeln('$name is new; it is not in ${golden.path}.');
      continue;
    }
    if (got == null) {
      out.writeln('$name is in ${golden.path} but was not recorded.');
      continue;
    }
    final String? difference = genUiSemanticsDiff(want, got);
    if (difference != null) out.writeln('$name:\n$difference');
  }

  if (out.isEmpty) return null;
  return '$out\nRe-record with '
      'GENUI_UPDATE_GOLDENS=1 if this is the change you meant to make.';
}

bool _updateRequested() {
  final String? value = Platform.environment['GENUI_UPDATE_GOLDENS'];
  return value != null && value.isNotEmpty && value != '0';
}

String _encode(Map<String, List<GenUiSemanticNode>> recorded) {
  final names = recorded.keys.toList()..sort();
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'components': <String, Object?>{
      for (final name in names)
        name: <Object?>[for (final node in recorded[name]!) node.toJson()],
    },
  });
}

Map<String, List<GenUiSemanticNode>> _decode(String source) {
  final Map<String, Object?> json = jsonDecode(source) as Map<String, Object?>;
  final Map<String, Object?> components =
      json['components'] as Map<String, Object?>? ?? const <String, Object?>{};
  return <String, List<GenUiSemanticNode>>{
    for (final entry in components.entries)
      entry.key: <GenUiSemanticNode>[
        for (final node in entry.value! as List<Object?>)
          GenUiSemanticNode.fromJson(node! as Map<String, Object?>),
      ],
  };
}
