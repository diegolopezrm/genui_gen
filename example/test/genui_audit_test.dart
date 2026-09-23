// What this catalog gives a person using a screen reader, and what it does
// not.
//
// The findings below are real and are genui's, not this package's: they are
// listed rather than hidden so that the list fails when one of them is fixed
// upstream, or when a new one appears in a widget of this app.

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';

void main() {
  testWidgets('the catalog is as accessible as it was', (tester) async {
    final recorded = <String, List<GenUiSemanticNode>>{};

    for (final item in exampleCatalog.items) {
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

/// The state of the basic catalog today, in the order the audit reports it.
///
/// Every one of these is genui's: an audio player whose play button and two
/// sliders announce nothing, an image that reaches assistive technology as
/// nothing at all (a2ui-project/a2ui#2740), and the basic slider, which has a
/// `label` property the catalog never passes on.
const List<String> _known = <String>[
  'AudioPlayer: unnamedControl (button)',
  'AudioPlayer: unnamedControl (slider)',
  'AudioPlayer: unnamedControl (slider)',
  'Image: exposesNothing',
  'Slider: unnamedControl (slider)',
];
