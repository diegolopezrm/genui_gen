import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart' as v1_0;
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';
import 'package:genui_gen/tracing.dart';

typedef JsonMap = Map<String, Object?>;

/// The basic catalog, under an id of the test's own.
CatalogImplementation get _catalog =>
    basicCatalog().derive(catalogId: 'dev.dlsoft.trace');

MessageProcessor<ComponentImplementation> _processor() {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [_catalog],
    defaultVersion: A2uiProtocolVersion.v0_9,
  );
  addTearDown(processor.dispose);
  return processor;
}

JsonMap _message(String kind, JsonMap body) => <String, Object?>{
  'version': 'v0.9',
  kind: <String, Object?>{'surfaceId': 's', ...body},
};

JsonMap _createSurface() =>
    _message('createSurface', {'catalogId': 'dev.dlsoft.trace'});

JsonMap _updateData(Object? value, {String path = '/'}) =>
    _message('updateDataModel', {'path': path, 'value': value});

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

bool _ticked(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox)).value!;

/// Records a session: the agent builds a surface, the user ticks the box and
/// presses the button.
Future<GenUiTrace> recordSession(
  WidgetTester tester, {
  List<String> redact = const <String>[],
}) async {
  final MessageProcessor<ComponentImplementation> processor = _processor();
  final recorder = GenUiTraceRecorder.attach(
    processor,
    catalogId: 'dev.dlsoft.trace',
    redact: redact,
    notes: const {'report': 'bug-4821'},
  );
  addTearDown(recorder.dispose);

  recorder.processMessages(_createSurface());
  recorder.processMessages(
    _message('updateComponents', {'components': _components}),
  );
  recorder.processMessages(
    _updateData({'on': false, 'user': 'ada@example.com'}),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: A2uiSurface(surface: processor.model.getSurface('s')!),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(Checkbox));
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
      expect(messages.map((m) => m.message.keys.last), [
        'createSurface',
        'updateComponents',
        'updateDataModel',
      ]);
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

    testWidgets('keeps what the app sent back in the surface\'s version', (
      tester,
    ) async {
      final processor = MessageProcessor<ComponentImplementation>(
        catalogs: [v1_0.basicCatalog().derive(catalogId: 'dev.dlsoft.trace')],
        defaultVersion: A2uiProtocolVersion.v1_0,
      );
      addTearDown(processor.dispose);
      final recorder = GenUiTraceRecorder.attach(processor);
      addTearDown(recorder.dispose);

      recorder.processMessages(<JsonMap>[
        for (final JsonMap message in [
          _createSurface(),
          _message('updateComponents', {
            'components': [
              {
                'id': 'root',
                'component': 'Button',
                'child': 'sendLabel',
                'action': {
                  'event': {'name': 'confirm'},
                },
              },
              // v1.0 ids are identifiers, so no hyphen as in the v0.9 session.
              {'id': 'sendLabel', 'component': 'Text', 'text': 'Confirm'},
            ],
          }),
        ])
          {...message, 'version': '1.0'},
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurface(surface: processor.model.getSurface('s')!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      final GenUiEventStep event = recorder
          .build()
          .steps
          .whereType<GenUiEventStep>()
          .single;
      expect((event.event! as Map<String, Object?>)['version'], '1.0');
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
      expect(_ticked(tester), isTrue);
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

      expect(_ticked(tester), isFalse);

      player.seekToEnd();
      await tester.pumpAndSettle();

      expect(_ticked(tester), isTrue);
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
      expect(_ticked(tester), isFalse);
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

  group('what reaches the file', () {
    late MessageProcessor<ComponentImplementation> processor;
    late GenUiTraceRecorder recorder;

    void start({List<String> redact = const <String>[]}) {
      processor = _processor();
      recorder = GenUiTraceRecorder.attach(processor, redact: redact);
      addTearDown(recorder.dispose);
      recorder.processMessages(_createSurface());
    }

    Map<String, Object?> sentValue() =>
        recorder
                .build()
                .steps
                .whereType<GenUiMessageStep>()
                .map((GenUiMessageStep s) => s.message['updateDataModel'])
                .whereType<Map<String, Object?>>()
                .single['value']!
            as Map<String, Object?>;

    test('a message is kept as the agent sent it, not as it was changed', () {
      start();
      recorder.processMessages(_updateData(<String, Object?>{'note': ''}));
      // The person types. The data model may be holding the very map the
      // message carried.
      processor.model.getSurface('s')!.dataModel.set('/note', 'typed');

      expect(sentValue()['note'], '');
    });

    test('redact covers what the agent sent, too', () {
      start(redact: const <String>['/user/email']);
      recorder.processMessages(
        _updateData(<String, Object?>{
          'user': <String, Object?>{'email': 'ada@example.com', 'name': 'Ada'},
        }),
      );

      final Map<String, Object?> user =
          sentValue()['user']! as Map<String, Object?>;
      expect(user['email'], '[redacted]');
      expect(user['name'], 'Ada');
    });

    test('redact follows a message that writes below the root', () {
      start(redact: const <String>['/user/email']);
      recorder.processMessages(
        _updateData(<String, Object?>{
          'email': 'ada@example.com',
        }, path: '/user'),
      );

      expect(sentValue()['email'], '[redacted]');
    });

    test('a message writing inside a redacted path is blanked whole', () {
      start(redact: const <String>['/user']);
      recorder.processMessages(
        _updateData('ada@example.com', path: '/user/email'),
      );

      final Object? update = recorder
          .build()
          .steps
          .whereType<GenUiMessageStep>()
          .last
          .message['updateDataModel'];
      expect((update! as Map)['value'], '[redacted]');
    });
  });
}
