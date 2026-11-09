// A session with this app's own widgets, recorded and replayed.
//
// The point of a trace is the bug you cannot reproduce: the screen the model
// composed once, from a context that will not come back. This records one,
// writes it, reads it back and replays it, which is the whole loop a bug
// report goes through.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/tracing.dart';

const _surfaceId = 'settings';

List<Map<String, Object?>> get _components => <Map<String, Object?>>[
  {
    'id': 'root',
    'component': 'PreferenceRow',
    'label': 'Weekly report',
    'enabled': {'path': '/notify'},
    'detail': 'Sent every Monday',
  },
];

void main() {
  testWidgets('a session with this catalog replays as it happened', (
    tester,
  ) async {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [exampleCatalog],
    );
    addTearDown(processor.dispose);
    final recorder = GenUiTraceRecorder.attach(
      processor,
      catalogId: exampleCatalog.id,
      notes: const {'report': 'the switch would not stay on'},
    );
    addTearDown(recorder.dispose);

    final String version = A2uiProtocolVersion.v0_9.jsonValue;
    recorder.handleMessage(
      CreateSurfaceMessage(
        version: version,
        surfaceId: _surfaceId,
        catalogId: exampleCatalog.id,
      ),
    );
    recorder.handleMessage(
      UpdateComponentsMessage(
        version: version,
        surfaceId: _surfaceId,
        components: _components,
      ),
    );
    recorder.handleMessage(
      UpdateDataModelMessage(
        version: version,
        surfaceId: _surfaceId,
        value: {'notify': false},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: A2uiSurface(surface: processor.model.getSurface(_surfaceId)!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // The file a user would attach to a bug report.
    final String file = recorder.build().encode();

    final player = GenUiTracePlayer(
      GenUiTrace.decode(file),
      catalog: exampleCatalog,
    )..seekToEnd();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GenUiTraceView(player: player)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly report'), findsOneWidget);
    expect(find.text('Sent every Monday'), findsOneWidget);
    // The user flipped it, and the replay is flipped too, without the agent.
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });
}
