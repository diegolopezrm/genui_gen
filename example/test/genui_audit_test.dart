// What this catalog gives a person using a screen reader, and what it does
// not.
//
// Findings are listed rather than hidden, so that the list fails when one of
// them is fixed, or when a new one appears in a widget of this app. Only the
// generated components are audited: the audit renders each component's
// examples, and a2ui_flutter's basic components carry none.

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

void main() {
  testWidgets('the catalog is as accessible as it was', (tester) async {
    final recorded = <String, List<GenUiSemanticNode>>{};

    for (final CatalogItem item
        in exampleCatalog.components.values.whereType<CatalogItem>()) {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiExampleSurface(catalog: exampleCatalog, item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();
      recorded[item.name] = genUiRenderedSemantics();
      handle.dispose();
    }

    final findings = genUiSemanticsAudit(
      recorded,
      // Decoration. A divider and an icon with nothing to say are correct.
      allowEmpty: const {'Divider', 'Icon'},
    );

    printOnFailure(findings.join('\n'));
    expect(findings.map((finding) => finding.toString()).toList(), _known);
  });
}

/// What the audit reports today, in the order it reports it: nothing.
///
/// With genui, every finding here was in its basic catalog, whose components
/// carried examples: an audio player whose play button and two sliders
/// announced nothing, an image that reached assistive technology as nothing at
/// all (a2ui-project/a2ui#2740), and a slider that dropped its `label`.
const List<String> _known = <String>[];
