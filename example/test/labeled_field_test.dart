import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders one surface holding a LabeledField with the agent's rules on it.
Future<MessageProcessor<ComponentImplementation>> show(
  WidgetTester tester, {
  String? seed,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [exampleCatalog],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);
  final String version = A2uiProtocolVersion.v0_9.jsonValue;
  processor.processMessages([
    {
      'version': version,
      'createSurface': {'surfaceId': 's', 'catalogId': exampleCatalog.id},
    },
    if (seed != null)
      {
        'version': version,
        'updateDataModel': {
          'surfaceId': 's',
          'value': {
            'form': {'email': seed},
          },
        },
      },
    {
      'version': version,
      'updateComponents': {
        'surfaceId': 's',
        'components': [
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
      },
    },
  ]);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: A2uiSurface(surface: processor.model.getSurface('s')!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return processor;
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
