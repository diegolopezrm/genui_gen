import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/testing.dart';
import 'package:genui_gen/tracing.dart';

Catalog get _catalog =>
    BasicCatalogItems.asCatalog().copyWith(catalogId: 'dev.dlsoft.trace');

/// The session every test records: a surface with a checkbox bound to `/on`
/// and a button that reports back.
List<JsonMap> get _components => <JsonMap>[
  {
    'id': 'root',
    'component': 'Column',
    'children': ['toggle', 'send'],
  },
  {
    'id': 'toggle',
    'component': 'CheckBox',
    'label': 'Notify me',
    'value': {'path': '/on'},
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

/// Records a session: the agent builds a surface, the user ticks the box and
/// presses the button.
Future<GenUiTrace> recordSession(
  WidgetTester tester, {
  List<String> redact = const <String>[],
}) async {
  final controller = SurfaceController(catalogs: [_catalog]);
  addTearDown(controller.dispose);
  final recorder = GenUiTraceRecorder.attach(
    controller,
    catalogId: 'dev.dlsoft.trace',
    redact: redact,
    notes: const {'report': 'bug-4821'},
  );
  addTearDown(recorder.dispose);

  recorder.handleMessage(
    core.UpdateComponentsMessage(surfaceId: 's', components: _components),
  );
  recorder.handleMessage(
    core.CreateSurfaceMessage(surfaceId: 's', catalogId: 'dev.dlsoft.trace'),
  );
  recorder.handleMessage(
    core.UpdateDataModelMessage(
      surfaceId: 's',
      value: {'on': false, 'user': 'ada@example.com'},
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Surface(surfaceContext: controller.contextFor('s'))),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();

  return recorder.build();
}

void main() {
  group('recording', () {
    testWidgets('keeps every message the agent sent', (tester) async {
      final trace = await recordSession(tester);

      final messages = trace.steps.whereType<GenUiMessageStep>().toList();
      expect(messages, hasLength(3));
      expect(messages.first.message.keys, contains('updateComponents'));
      expect(trace.surfaceIds, ['s']);
      expect(trace.catalogId, 'dev.dlsoft.trace');
      expect(trace.notes['report'], 'bug-4821');
    });

    testWidgets('keeps what the user changed', (tester) async {
      final trace = await recordSession(tester);

      final data = trace.steps.whereType<GenUiDataStep>().toList();
      expect(data, isNotEmpty);
      // The last snapshot is after the tick: the agent sent `false`, the user
      // made it `true`, and that write never went through the agent.
      expect((data.last.data! as Map)['on'], isTrue);
    });

    testWidgets('keeps what the app sent back', (tester) async {
      final trace = await recordSession(tester);

      final events = trace.steps.whereType<GenUiEventStep>().toList();
      expect(events, hasLength(1));
      expect(events.single.event.toString(), contains('confirm'));
    });

    testWidgets('leaves out what it was told to redact', (tester) async {
      final trace = await recordSession(tester, redact: const ['/user']);

      final data = trace.steps.whereType<GenUiDataStep>().toList();
      expect((data.last.data! as Map)['user'], '[redacted]');
      // The value beside it is untouched.
      expect((data.last.data! as Map)['on'], isTrue);
    });

    testWidgets('survives being written and read back', (tester) async {
      final trace = await recordSession(tester);

      final GenUiTrace read = GenUiTrace.decode(trace.encode());

      expect(read.steps, hasLength(trace.steps.length));
      expect(read.catalogId, trace.catalogId);
      expect(read.recordedAt, trace.recordedAt);
      expect(read.encode(), trace.encode());
    });

    test('refuses a format it does not know', () {
      expect(
        () => GenUiTrace.decode('{"version": 99, "steps": []}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('replay', () {
    testWidgets('rebuilds the surface the session ended on', (tester) async {
      final trace = GenUiTrace.decode((await recordSession(tester)).encode());
      final player = GenUiTracePlayer(trace, catalog: _catalog)..seekToEnd();
      addTearDown(player.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUiTraceView(player: player)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notify me'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      // The user's tick is part of the session, so the replay is ticked too.
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });

    testWidgets('stops where it is told to', (tester) async {
      final trace = GenUiTrace.decode((await recordSession(tester)).encode());
      final player = GenUiTracePlayer(trace, catalog: _catalog);
      addTearDown(player.dispose);

      // Up to the third message: the surface exists and the agent's data has
      // arrived, but the user has not touched it yet.
      player.seek(3);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUiTraceView(player: player)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );

      player.seekToEnd();
      await tester.pumpAndSettle();

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });

    testWidgets('rewinds by rebuilding, not by guessing', (tester) async {
      final trace = GenUiTrace.decode((await recordSession(tester)).encode());
      final player = GenUiTracePlayer(trace, catalog: _catalog)..seekToEnd();
      addTearDown(player.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUiTraceView(player: player)),
        ),
      );
      await tester.pumpAndSettle();

      player.seek(3);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUiTraceView(player: player)),
        ),
      );
      await tester.pumpAndSettle();

      expect(player.position, 3);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    });

    testWidgets('a replayed session can be held to its semantics', (
      tester,
    ) async {
      final trace = GenUiTrace.decode((await recordSession(tester)).encode());
      final player = GenUiTracePlayer(trace, catalog: _catalog)..seekToEnd();
      addTearDown(player.dispose);

      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUiTraceView(player: player)),
        ),
      );
      await tester.pumpAndSettle();

      final nodes = genUiRenderedSemantics();
      handle.dispose();

      expect(
        nodes.map((node) => node.role),
        containsAll(['checkbox', 'button']),
      );
      expect(
        nodes.firstWhere((node) => node.role == 'checkbox').state['checked'],
        isTrue,
      );
    });
  });
}
