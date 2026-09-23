// A session with this app's own widgets, recorded and replayed.
//
// The point of a trace is the bug you cannot reproduce: the screen the model
// composed once, from a context that will not come back. This records one,
// writes it, reads it back and replays it, which is the whole loop a bug
// report goes through.

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';

const _surfaceId = 'settings';

List<JsonMap> get _components => <JsonMap>[
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
    final controller = SurfaceController(catalogs: [exampleCatalog]);
    addTearDown(controller.dispose);
    final recorder = GenUiTraceRecorder.attach(
      controller,
      catalogId: exampleCatalog.catalogId,
      notes: const {'report': 'the switch would not stay on'},
    );
    addTearDown(recorder.dispose);

    recorder.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: _surfaceId,
        components: _components,
      ),
    );
    recorder.handleMessage(
      core.CreateSurfaceMessage(
        surfaceId: _surfaceId,
        catalogId: exampleCatalog.catalogId!,
      ),
    );
    recorder.handleMessage(
      core.UpdateDataModelMessage(
        surfaceId: _surfaceId,
        value: {'notify': false},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Surface(surfaceContext: controller.contextFor(_surfaceId)),
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
      MaterialApp(home: Scaffold(body: GenUiTraceView(player: player))),
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
