// The generated components, rendered by a2ui_flutter from the messages an
// agent would send: one message processor, one surface, the basic catalog
// next to the generated one.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:example/genui_catalog.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart' show genUiCatalogJson;

const String _surfaceId = 'main';

/// The generated components and functions under the generated catalog's id,
/// with the basic ones an agent composes them with.
final CatalogImplementation _catalog = CatalogImplementation(
  id: genUiCatalog.id,
  components: [...BasicComponents.all, ...genUiCatalogItems],
  functions: [
    ...BasicCatalog.v0_9().functions.values,
    ...genUiCatalogFunctions,
  ],
  themeSchema: BasicComponents.api.themeSchema,
);

Map<String, Object?> _message(String kind, Map<String, Object?> body) => {
  'version': 'v0.9',
  kind: {'surfaceId': _surfaceId, ...body},
};

Map<String, Object?> _components(List<Map<String, Object?>> components) =>
    _message('updateComponents', {'components': components});

Map<String, Object?> _data(Object? value, {String path = '/'}) =>
    _message('updateDataModel', {'path': path, 'value': value});

/// One surface rendered from the messages sent to it.
class _Surface {
  _Surface(this._tester);

  final WidgetTester _tester;

  final MessageProcessor<ComponentImplementation> processor =
      MessageProcessor<ComponentImplementation>(
        catalogs: [_catalog],
        defaultVersion: A2uiProtocolVersion.v0_9,
      );

  final List<A2uiClientAction> actions = [];
  final List<A2uiClientError> errors = [];

  SurfaceModel<ComponentImplementation> get model =>
      processor.groupModel.getSurface(_surfaceId)!;

  Object? data(String path) => model.dataModel.get(path);

  void process(List<Map<String, Object?>> messages) =>
      processor.processMessages(
        AgentToRendererMessagePayload.fromJson(
          messages,
          protocolVersion: A2uiProtocolVersion.v0_9,
        ),
      );

  Future<void> send(List<Map<String, Object?>> messages) async {
    process(messages);
    await _tester.pump();
  }

  static Future<_Surface> pump(
    WidgetTester tester,
    List<Map<String, Object?>> components, {
    Object? data,
  }) async {
    final surface = _Surface(tester);
    final SurfaceGroupModel<ComponentImplementation> group =
        surface.processor.groupModel;
    group.onAction.addListener(surface.actions.add);
    group.onSurfaceCreated.addListener(
      (model) => model.onError.addListener(surface.errors.add),
    );
    addTearDown(group.dispose);
    surface.process([
      _message('createSurface', {'catalogId': _catalog.id}),
      if (data != null) _data(data),
      _components(components),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: A2uiSurface(surface: surface.model),
          ),
        ),
      ),
    );
    return surface;
  }
}

void main() {
  unknownPropertyMain();
  testWidgets('a panel renders its children and sends its close event', (
    tester,
  ) async {
    final surface = await _Surface.pump(
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
      data: {'title': 'Settings'},
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

    await surface.send([_data('Profile', path: '/title')]);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('a bound switch writes back, and a literal one is read-only', (
    tester,
  ) async {
    final surface = await _Surface.pump(
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
      data: {
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
    expect(surface.data('/prefs/notify'), isTrue);
    expect(switchOf('Notifications').value, isTrue);
    expect(surface.errors, isEmpty);
  });

  testWidgets('a field shows the message of the check that fails', (
    tester,
  ) async {
    final surface = await _Surface.pump(
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
      data: {'name': ''},
    );

    expect(find.text('Tell us your name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Ada');
    await tester.pump();
    expect(surface.data('/name'), 'Ada');
    expect(find.text('Tell us your name.'), findsNothing);
  });

  testWidgets('a template list grows with the data', (tester) async {
    final surface = await _Surface.pump(
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
      data: {
        'tasks': [
          {'name': 'Write the test'},
        ],
      },
    );

    expect(find.text('Write the test'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsNothing);

    await surface.send([
      _data([
        {'name': 'Write the test'},
        {'name': 'Ship it'},
      ], path: '/tasks'),
    ]);
    expect(find.text('Ship it'), findsOneWidget);

    await surface.send([_data(<Object?>[], path: '/tasks')]);
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('data objects decode, and a bound one missing a field is '
      'reported to the agent', (tester) async {
    final surface = await _Surface.pump(
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
      data: {
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
    await surface.send([_data('x', path: '/unrelated')]);
    await tester.pump();
    expect(surface.errors, hasLength(1));
  });

  testWidgets('generated functions compute what the agent binds', (
    tester,
  ) async {
    await _Surface.pump(
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
      data: {'person': 'Ada Lovelace'},
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('1234.56'), findsOneWidget);
  });

  testWidgets('a component missing a required property is rejected', (
    tester,
  ) async {
    final surface = _Surface(tester);
    addTearDown(surface.processor.groupModel.dispose);
    expect(
      () => surface.process([
        _message('createSurface', {'catalogId': _catalog.id}),
        _components([
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
    final surface = _Surface(tester);
    addTearDown(surface.processor.groupModel.dispose);
    expect(
      () => surface.process([
        _message('createSurface', {'catalogId': _catalog.id}),
        _components([
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
