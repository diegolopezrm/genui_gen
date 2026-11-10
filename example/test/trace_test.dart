// A session with this app's own widgets, recorded and replayed.
//
// The point of a trace is the bug you cannot reproduce: the screen the agent
// composed once, from a context that will not come back. This records one,
// writes it, reads it back and replays it, which is the whole loop a bug
// report goes through.

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/tracing.dart';

import 'support/surface.dart';

const _surface = 'settings';

void main() {
  testWidgets('a session with this catalog replays as it happened', (
    tester,
  ) async {
    final processor = exampleProcessor();
    final recorder = GenUiTraceRecorder.attach(
      processor,
      catalogId: exampleCatalog.id,
      notes: const {'report': 'the switch would not stay on'},
    );
    addTearDown(recorder.dispose);

    recorder.processMessages([
      createSurface(surface: _surface),
      components([
        {
          'id': 'root',
          'component': 'PreferenceRow',
          'label': 'Weekly report',
          'enabled': {'path': '/notify'},
          'detail': 'Sent every Monday',
        },
      ], surface: _surface),
      data({'notify': false}, surface: _surface),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: A2uiSurface(surface: processor.model.getSurface(_surface)!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
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
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(player.rejections, isEmpty);
  });
}
