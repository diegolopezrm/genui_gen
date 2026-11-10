// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// Renders one surface holding a LabeledField with the agent's rules on it.
Future<ExampleSurface> show(WidgetTester tester, {String? seed}) =>
    ExampleSurface.pump(
      tester,
      [
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
      initialData: seed == null
          ? null
          : {
              'form': {'email': seed},
            },
    );

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
    final ExampleSurface surface = await show(tester, seed: '');
    expect(find.text('We need an email to reach you.'), findsOneWidget);

    // @GenUiWrites puts it in the data model, @GenUiChecked reads the rule
    // against the same path. No message goes back to the agent in between.
    await tester.enterText(find.byType(TextFormField), 'diego@example.com');
    await tester.pumpAndSettle();

    expect(find.text('We need an email to reach you.'), findsNothing);
    expect(surface.read('/form/email'), 'diego@example.com');
    expect(surface.actions, isEmpty);
  });
}
