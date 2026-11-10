// The end-to-end claim of `@GenUiWrites`: flipping the switch that the
// generated builder wired up puts the new value in the surface's data model,
// and the component reads it back from there.

// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

Switch _switch(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch));

void main() {
  testWidgets('the switch writes to the path the agent bound', (tester) async {
    final ExampleSurface surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'PreferenceRow',
          'label': 'Weekly summary',
          'enabled': {'path': '/settings/notify'},
        },
      ],
      initialData: {
        'settings': {'notify': false},
      },
    );

    expect(_switch(tester).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(surface.read('/settings/notify'), isTrue);
    expect(_switch(tester).value, isTrue);
  });

  testWidgets('a literal is shown, and has nowhere to be written', (
    tester,
  ) async {
    await ExampleSurface.pump(tester, [
      {
        'id': 'root',
        'component': 'PreferenceRow',
        'label': 'Weekly summary',
        'enabled': true,
      },
    ]);

    // The agent named no path, so the switch shows the literal and, like a
    // basic CheckBox with a literal value, cannot be flipped.
    expect(_switch(tester).value, isTrue);
    expect(_switch(tester).onChanged, isNull);
  });
}
