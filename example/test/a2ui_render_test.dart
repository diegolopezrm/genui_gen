// The generated components, rendered by a2ui_flutter from the messages an
// agent would send: one message processor, one surface, the basic catalog
// next to the generated one.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:example/genui_catalog.g.dart';
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart' show genUiCatalogJson;

import 'support/surface.dart';

void main() {
  unknownPropertyMain();
  testWidgets('a panel renders its children and sends its close event', (
    tester,
  ) async {
    final surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Panel',
          'title': {'path': '/title'},
          'child': 'body',
          'actions': ['ok'],
          'onClose': {
            'event': {'name': 'panel_closed'},
          },
          'meta': {'Owner': 'Ada'},
        },
        {'id': 'body', 'component': 'Text', 'text': 'Inside the panel'},
        {
          'id': 'ok',
          'component': 'Button',
          'child': 'okLabel',
          'action': {
            'event': {'name': 'confirmed'},
          },
        },
        {'id': 'okLabel', 'component': 'Text', 'text': 'OK'},
      ],
      initialData: {'title': 'Settings'},
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Inside the panel'), findsOneWidget);
    expect(find.text('Owner: Ada'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(
      [for (final a in surface.actions) a.name],
      ['panel_closed', 'confirmed'],
    );

    await surface.send([data('Profile', path: '/title')]);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('a bound switch writes back, and a literal one is read-only', (
    tester,
  ) async {
    final surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['bound', 'literal'],
        },
        {
          'id': 'bound',
          'component': 'PreferenceRow',
          'label': 'Notifications',
          'enabled': {'path': '/prefs/notify'},
        },
        {
          'id': 'literal',
          'component': 'PreferenceRow',
          'label': 'Dark mode',
          'enabled': true,
        },
      ],
      initialData: {
        'prefs': {'notify': false},
      },
    );

    Switch switchOf(String label) => tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SwitchListTile, label),
        matching: find.byType(Switch),
      ),
    );

    expect(switchOf('Notifications').value, isFalse);
    expect(switchOf('Notifications').onChanged, isNotNull);
    expect(switchOf('Dark mode').value, isTrue);
    expect(switchOf('Dark mode').onChanged, isNull);

    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(surface.read('/prefs/notify'), isTrue);
    expect(switchOf('Notifications').value, isTrue);
    expect(surface.errors, isEmpty);
  });

  testWidgets('a field shows the message of the check that fails', (
    tester,
  ) async {
    final surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'LabeledField',
          'label': 'Name',
          'value': {'path': '/name'},
          'checks': [
            {
              'condition': {
                'call': 'required',
                'args': {
                  'value': {'path': '/name'},
                },
              },
              'message': 'Tell us your name.',
            },
          ],
        },
      ],
      initialData: {'name': ''},
    );

    expect(find.text('Tell us your name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Ada');
    await tester.pump();
    expect(surface.read('/name'), 'Ada');
    expect(find.text('Tell us your name.'), findsNothing);
  });

  testWidgets('a template list grows with the data', (tester) async {
    final surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'TaskList',
          'title': 'Today',
          'rows': {'componentId': 'row', 'path': '/tasks'},
        },
        {
          'id': 'row',
          'component': 'Text',
          'text': {'path': 'name'},
        },
      ],
      initialData: {
        'tasks': [
          {'name': 'Write the test'},
        ],
      },
    );

    expect(find.text('Write the test'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsNothing);

    await surface.send([
      data([
        {'name': 'Write the test'},
        {'name': 'Ship it'},
      ], path: '/tasks'),
    ]);
    expect(find.text('Ship it'), findsOneWidget);

    await surface.send([data(<Object?>[], path: '/tasks')]);
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('data objects decode, and a bound one missing a field is '
      'reported to the agent', (tester) async {
    final surface = await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['literal', 'bound'],
        },
        {
          'id': 'literal',
          'component': 'MetricsTable',
          'title': 'Literal',
          'rows': [
            {'label': 'Revenue', 'value': 12.5, 'trend': 'up'},
          ],
        },
        {
          'id': 'bound',
          'component': 'MetricsTable',
          'title': 'Bound',
          'rows': {'path': '/metrics'},
        },
      ],
      initialData: {
        'metrics': [
          {'value': 3, 'trend': 'down'},
        ],
      },
    );
    await tester.pump();

    expect(find.text('Revenue'), findsOneWidget);
    expect(surface.errors, hasLength(1));
    expect(surface.errors.single.code, 'VALIDATION_FAILED');
    expect(surface.errors.single.path, '/rows/label');

    // Reported once, however often the component rebuilds.
    await surface.send([data('x', path: '/unrelated')]);
    await tester.pump();
    expect(surface.errors, hasLength(1));
  });

  testWidgets('generated functions compute what the agent binds', (
    tester,
  ) async {
    await ExampleSurface.pump(
      tester,
      [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['name', 'price'],
        },
        {
          'id': 'name',
          'component': 'Text',
          'text': {
            'call': 'shortenName',
            'args': {
              'name': {'path': '/person'},
              'style': 'firstOnly',
            },
            'returnType': 'string',
          },
        },
        {
          'id': 'price',
          'component': 'Text',
          'text': {
            'call': 'formatPrice',
            'args': {'cents': 123456},
            'returnType': 'string',
          },
        },
      ],
      initialData: {'person': 'Ada Lovelace'},
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('1234.56'), findsOneWidget);
  });

  testWidgets('a component missing a required property is rejected', (
    tester,
  ) async {
    final processor = exampleProcessor();
    expect(
      () => processor.processMessages([
        createSurface(),
        components([
          {'id': 'root', 'component': 'ProductCard', 'price': 3},
        ]),
      ]),
      throwsA(isA<A2uiError>()),
    );
  });

  test('the catalog document describes the generated components', () {
    final Map<String, Object?> json = genUiCatalogJson(genUiCatalog);
    expect(json['catalogId'], 'dev.dlsoft.genui_gen.example');
    final components = json['components']! as Map<String, Object?>;
    final panel = components['Panel']! as Map<String, Object?>;
    final properties = panel['properties']! as Map<String, Object?>;
    expect(properties.keys, containsAll(['title', 'child', 'accessibility']));
    expect(properties['child'], {
      r'$ref': r'#/$defs/ComponentId',
      'description': 'The component rendered as the body of the panel.',
    });
    expect(panel['required'], containsAll(['title', 'child']));
    final functions = json['functions']! as Map<String, Object?>;
    expect(functions.keys, contains('shortenName'));
  });
}

void unknownPropertyMain() {
  testWidgets('a property the widget does not take is rejected', (
    tester,
  ) async {
    final processor = exampleProcessor();
    expect(
      () => processor.processMessages([
        createSurface(),
        components([
          {
            'id': 'root',
            'component': 'ProductCard',
            'title': 'Mug',
            'price': 3,
            'colour': 'red',
          },
        ]),
      ]),
      throwsA(isA<A2uiError>()),
    );
  });
}
