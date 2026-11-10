// What this catalog gives a person using a screen reader, and what it does
// not.
//
// The app's own components are audited from their generated examples. The
// basic components carry no examples in a2ui_flutter, so a few are written
// out here, and what they expose today is listed rather than hidden: the list
// fails when one of them is fixed upstream, or when a new finding appears.

import 'package:example/genui_catalog.g.dart';
import 'package:example/main.dart';
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

import 'support/surface.dart';

/// Basic components as an agent composes them, each with the label or
/// description it would give.
const Map<String, List<JsonMap>> _basics = {
  'Button': [
    {
      'id': 'root',
      'component': 'Button',
      'child': 'label',
      'action': {
        'event': {'name': 'go'},
      },
    },
    {'id': 'label', 'component': 'Text', 'text': 'Go'},
  ],
  'CheckBox': [
    {
      'id': 'root',
      'component': 'CheckBox',
      'label': 'Notify me',
      'value': {'path': '/on'},
    },
  ],
  'TextField': [
    {
      'id': 'root',
      'component': 'TextField',
      'label': 'Name',
      'value': {'path': '/name'},
    },
  ],
  'Slider': [
    {
      'id': 'root',
      'component': 'Slider',
      'label': 'Volume',
      'value': {'path': '/volume'},
      'min': 0,
      'max': 100,
    },
  ],
  'Image': [
    {
      'id': 'root',
      'component': 'Image',
      'url': 'https://example.com/cat.png',
      'description': 'A cat asleep on a keyboard',
    },
  ],
  'Icon': [
    {'id': 'root', 'component': 'Icon', 'name': 'home'},
  ],
  'Divider': [
    {'id': 'root', 'component': 'Divider'},
  ],
};

/// What the basic components fail today, in the order the audit reports it.
///
/// Nothing, since a2ui_flutter 0.1.0: an image that fails to load, which
/// every network image does in a test, labels its broken-image icon with the
/// description the agent gave it.
const List<String> _knownBasic = <String>[];

void main() {
  testWidgets('the generated components announce what they show', (
    tester,
  ) async {
    final recorded = <String, List<GenUiSemanticNode>>{};

    for (final GenUiComponent component in genUiCatalogItems) {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiExampleSurface(
              catalog: exampleCatalog,
              component: component,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      recorded[component.name] = genUiRenderedSemantics();
      handle.dispose();
    }

    final findings = genUiSemanticsAudit(recorded);
    expect(findings.map((finding) => finding.toString()), isEmpty);
  });

  testWidgets('the basic components, as a2ui_flutter draws them today', (
    tester,
  ) async {
    final recorded = <String, List<GenUiSemanticNode>>{};

    for (final MapEntry<String, List<JsonMap>> basic in _basics.entries) {
      final SemanticsHandle handle = tester.ensureSemantics();
      await ExampleSurface.pump(
        tester,
        basic.value,
        initialData: {'on': false, 'name': '', 'volume': 40},
      );
      recorded[basic.key] = genUiRenderedSemantics();
      handle.dispose();
    }

    final findings = genUiSemanticsAudit(
      recorded,
      // Decoration. A divider and an icon with nothing to say are correct.
      allowEmpty: const {'Divider', 'Icon'},
    );
    printOnFailure(findings.join('\n'));
    expect(findings.map((finding) => finding.toString()).toList(), _knownBasic);

    // Not an unnamed control, so the audit passes it, but named by its value:
    // a screen reader says "40, 40%" and reads "Volume" as a separate line.
    // When this fails, the slider carries its label and the line can go.
    final GenUiSemanticNode slider = recorded['Slider']!.singleWhere(
      (node) => node.role == 'slider',
    );
    expect(slider.name, '40');
  });
}
