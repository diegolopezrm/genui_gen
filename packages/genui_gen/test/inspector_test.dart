import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/inspector.dart';
import 'package:genui_gen/tracing.dart';

typedef JsonMap = Map<String, Object?>;

/// The basic catalog, under an id of the test's own.
CatalogImplementation get _catalog =>
    basicCatalog().derive(catalogId: 'dev.dlsoft.inspect');

/// A surface with a checkbox bound to `/on`, a line of text bound to a path
/// the agent never wrote, and a button.
List<JsonMap> get _components => <JsonMap>[
  {
    'id': 'root',
    'component': 'Column',
    'children': ['toggle', 'note', 'send'],
  },
  {
    'id': 'toggle',
    'component': 'CheckBox',
    'label': 'Notify me',
    'value': {'path': '/on'},
  },
  {
    'id': 'note',
    'component': 'Text',
    'text': {'path': '/note'},
  },
  {
    'id': 'send',
    'component': 'Button',
    'child': 'send-label',
    'action': {
      'event': {'name': 'confirm'},
    },
  },
  {'id': 'send-label', 'component': 'Text', 'text': 'Confirm'},
];

/// Renders whatever surfaces the processor has, rebuilding as they arrive.
///
/// The inspector's own child is handed to it once and never rebuilt by it, so
/// the app under the panel has to follow the processor itself, exactly as a
/// real one does.
class _LiveSurfaces extends StatefulWidget {
  const _LiveSurfaces(this.processor);

  final MessageProcessor<ComponentImplementation> processor;

  @override
  State<_LiveSurfaces> createState() => _LiveSurfacesState();
}

class _LiveSurfacesState extends State<_LiveSurfaces> {
  SurfaceGroupModel<ComponentImplementation> get _group =>
      widget.processor.model;

  late final List<Subscription> _subscriptions;

  @override
  void initState() {
    super.initState();
    _subscriptions = <Subscription>[
      _group.onSurfaceCreated.subscribe((_) => setState(() {})),
      _group.onSurfaceDeleted.subscribe((_) => setState(() {})),
    ];
  }

  @override
  void dispose() {
    for (final Subscription subscription in _subscriptions) {
      subscription.unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final SurfaceModel<ComponentImplementation> surface
            in _group.allSurfaces)
          A2uiSurface(key: ObjectKey(surface), surface: surface),
      ],
    ),
  );
}

/// Pumps the inspector over a live surface and opens the panel.
/// A surface built from a template: one component repeated over `/items`,
/// reading a path written relative to the row it renders.
List<JsonMap> get _templateComponents => <JsonMap>[
  {
    'id': 'root',
    'component': 'Column',
    'children': {'componentId': 'row', 'path': '/items'},
  },
  {
    'id': 'row',
    'component': 'Text',
    'text': {'path': 'label'},
  },
];

Future<void> pumpInspector(
  WidgetTester tester, {
  bool withRecorder = false,
  bool enabled = true,
  bool template = false,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [_catalog],
    defaultVersion: A2uiProtocolVersion.v0_9,
  );
  addTearDown(processor.dispose);

  GenUiTraceRecorder? recorder;
  if (withRecorder) {
    recorder = GenUiTraceRecorder.attach(processor, catalogId: 'x');
    addTearDown(recorder.dispose);
  }
  final void Function(Object? payload) send =
      recorder?.processMessages ?? processor.processMessages;

  await tester.pumpWidget(
    MaterialApp(
      home: GenUiInspector(
        processor: processor,
        recorder: recorder,
        enabled: enabled,
        child: _LiveSurfaces(processor),
      ),
    ),
  );

  JsonMap message(String kind, JsonMap body) => <String, Object?>{
    'version': 'v0.9',
    kind: <String, Object?>{'surfaceId': 's', ...body},
  };
  send(message('createSurface', {'catalogId': 'dev.dlsoft.inspect'}));
  send(
    message('updateComponents', {
      'components': template ? _templateComponents : _components,
    }),
  );
  send(
    message('updateDataModel', {
      'path': '/',
      'value': template
          ? {
              'items': [
                {'label': 'Call the dentist'},
                {'label': 'Renew the passport'},
              ],
            }
          : {'on': false, 'seen': 3},
    }),
  );
  await tester.pumpAndSettle();

  if (!enabled) return;
  await tester.tap(find.textContaining('a2ui'));
  await tester.pumpAndSettle();
}

void main() {
  group('GenUiInspector', () {
    testWidgets('is not there at all when it is off', (tester) async {
      await pumpInspector(tester, enabled: false);

      expect(find.textContaining('a2ui'), findsNothing);
      // The app itself is untouched.
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('the handle counts the surfaces and opens the panel', (
      tester,
    ) async {
      await pumpInspector(tester);

      expect(find.text('tree'), findsOneWidget);
      expect(find.text('data'), findsOneWidget);
      expect(find.text('semantics'), findsOneWidget);
      // No recorder, so nothing to show a session from.
      expect(find.text('messages'), findsNothing);
    });

    testWidgets('the tree shows the components the model built', (
      tester,
    ) async {
      await pumpInspector(tester);

      expect(find.text('5 components on s, bound to 2 paths.'), findsOneWidget);
      expect(find.textContaining('CheckBox'), findsOneWidget);
      // The path a component binds is on its row.
      expect(find.text('/on'), findsOneWidget);
    });

    testWidgets('a row opens into the properties the agent sent', (
      tester,
    ) async {
      await pumpInspector(tester);

      await tester.tap(find.textContaining('CheckBox'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"label": "Notify me"'), findsOneWidget);
    });

    testWidgets('the data tab shows each path, its value and who reads it', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.text('data'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/on'), findsOneWidget);
      expect(find.text('toggle'), findsOneWidget);
    });

    testWidgets('the data tab flags a path no component reads', (tester) async {
      await pumpInspector(tester);
      await tester.tap(find.text('data'));
      await tester.pumpAndSettle();

      // `/seen` was sent with the data model and nothing on the surface binds
      // it, so it is payload the agent paid for and the user never saw.
      expect(find.textContaining('/seen'), findsOneWidget);
      expect(find.text('no component reads it'), findsOneWidget);
    });

    testWidgets('a path inside a template is matched row by row', (
      tester,
    ) async {
      await pumpInspector(tester, template: true);
      await tester.tap(find.text('data'));
      await tester.pumpAndSettle();

      // `row` binds `label`, written relative to the row it renders. Every
      // row it resolves to is a real entry, so none of them is a finding.
      expect(
        find.textContaining('/items/0/label  "Call the dentist"'),
        findsOneWidget,
      );
      expect(find.text('row'), findsNWidgets(2));
      expect(find.textContaining('not in the data model'), findsNothing);
      // And the list the template repeats over is a binding of its holder,
      // which is what tells it how many rows there are.
      expect(find.textContaining('/items  2 items'), findsOneWidget);
    });

    testWidgets('the data tab flags a binding with nothing behind it', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.text('data'));
      await tester.pumpAndSettle();

      // `note` binds `/note`, which never arrived: the usual reason a field
      // renders empty with no error anywhere.
      expect(
        find.textContaining('/note  not in the data model'),
        findsOneWidget,
      );
    });

    testWidgets('the data tab follows the user, not just the agent', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.text('data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('false'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.textContaining('true'), findsOneWidget);
    });

    testWidgets('the semantics tab reports the app and not itself', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.text('semantics'));
      await tester.pumpAndSettle();

      // What a screen reader gets from the surface, role and name.
      expect(find.textContaining('checkbox   Notify me'), findsOneWidget);
      expect(find.textContaining('button     Confirm'), findsOneWidget);
      // And nothing from the panel, which excludes itself: its own tabs are
      // unnamed controls and would be the first thing an audit reported.
      expect(find.textContaining('no name'), findsNothing);
    });

    testWidgets('the messages tab lists the session', (tester) async {
      await pumpInspector(tester, withRecorder: true);
      await tester.tap(find.text('messages'));
      await tester.pumpAndSettle();

      expect(find.textContaining('updateComponents'), findsOneWidget);
      expect(find.textContaining('createSurface'), findsOneWidget);
    });

    testWidgets('a message opens into what the agent actually sent', (
      tester,
    ) async {
      await pumpInspector(tester, withRecorder: true);
      await tester.tap(find.text('messages'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('createSurface'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('"catalogId": "dev.dlsoft.inspect"'),
        findsOneWidget,
      );
    });

    testWidgets('closing it leaves the app alone', (tester) async {
      await pumpInspector(tester);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(find.text('tree'), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
    });
  });
}
