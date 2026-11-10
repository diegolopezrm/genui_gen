import 'package:a2ui_flutter/basic_catalog.dart' as v1_0;
import 'package:a2ui_flutter/v0_9/basic_catalog.dart' as v0_9;
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

/// A component whose example puts a basic `Text` inside it, so the surface
/// resolves a basic component of the catalog's own protocol version too.
final GenUiComponent _frame = GenUiComponent(
  name: 'Frame',
  schema: GenUiSchemas.component(
    description: 'A frame around one child.',
    properties: {'child': GenUiSchemas.componentId()},
    required: ['child'],
  ),
  examples: [
    r'''
[
  {"id": "root", "component": "Frame", "child": "inside"},
  {"id": "inside", "component": "Text", "text": "Framed"}
]''',
  ],
  builder: (context, node, props, buildChild) => DecoratedBox(
    decoration: BoxDecoration(border: Border.all()),
    child: switch (props.child('child')) {
      final child? => buildChild(child),
      null => null,
    },
  ),
);

Future<void> _pump(WidgetTester tester, CatalogImplementation catalog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GenUiExampleSurface(catalog: catalog, component: _frame),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('GenUiExampleSurface', () {
    testWidgets('renders an example on a v0.9 catalog', (tester) async {
      await _pump(
        tester,
        v0_9.basicCatalog().derive(
          catalogId: 'dev.dlsoft.v0_9',
          addComponents: [_frame],
        ),
      );

      expect(find.text('Framed'), findsOneWidget);
    });

    testWidgets('renders an example on a v1.0 catalog, in v1.0 messages', (
      tester,
    ) async {
      // A v0.9 message would be refused here: a surface cannot mix protocol
      // versions with its catalog.
      await _pump(
        tester,
        v1_0.basicCatalog().derive(
          catalogId: 'dev.dlsoft.v1_0',
          addComponents: [_frame],
        ),
      );

      expect(find.text('Framed'), findsOneWidget);
    });
  });
}
