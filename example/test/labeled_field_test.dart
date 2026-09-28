import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// Renders one surface holding a LabeledField with the agent's rules on it.
Future<SurfaceController> show(WidgetTester tester, {String? seed}) async {
  final controller = SurfaceController(catalogs: [exampleCatalog]);
  addTearDown(controller.dispose);
  controller.handleMessage(
    core.UpdateComponentsMessage(
      surfaceId: 's',
      components: [
        {
          'id': 'root',
          'component': 'LabeledField',
          'label': 'Email',
          'value': {'path': '/form/email'},
          'checks': [
            {
              'condition': {
                'call': 'required',
                'args': {
                  'value': {'path': '/form/email'},
                },
              },
              'message': 'We need an email to reach you.',
            },
          ],
        },
      ],
    ),
  );
  controller.handleMessage(
    core.CreateSurfaceMessage(
      surfaceId: 's',
      catalogId: exampleCatalog.catalogId!,
    ),
  );
  if (seed != null) {
    controller.handleMessage(
      core.UpdateDataModelMessage(
        surfaceId: 's',
        value: {
          'form': {'email': seed},
        },
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Surface(surfaceContext: controller.contextFor('s'))),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('the agent\'s rule speaks in the agent\'s words', (tester) async {
    await show(tester, seed: '');
    expect(find.text('We need an email to reach you.'), findsOneWidget);
  });

  testWidgets('and stops once the value satisfies it', (tester) async {
    await show(tester, seed: 'diego@example.com');
    expect(find.text('We need an email to reach you.'), findsNothing);
  });

  testWidgets('what the user types clears it without the agent involved', (
    tester,
  ) async {
    await show(tester, seed: '');
    expect(find.text('We need an email to reach you.'), findsOneWidget);

    // @GenUiWrites puts it in the data model, @GenUiChecked reads the rule
    // against the same path. No message goes back to the agent in between.
    await tester.enterText(find.byType(TextFormField), 'diego@example.com');
    await tester.pumpAndSettle();

    expect(find.text('We need an email to reach you.'), findsNothing);
  });
}
