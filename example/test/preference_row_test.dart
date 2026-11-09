// The end-to-end claim of `@GenUiWrites`: flipping the switch that the
// generated builder wired up puts the new value in the surface's data model,
// and the component reads it back from there.
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders a PreferenceRow `pref-1` with [properties], under a Column root.
Future<SurfaceModel<ComponentImplementation>> pumpItem(
  WidgetTester tester, {
  required Map<String, Object?> properties,
  Map<String, Object?>? data,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [exampleCatalog],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);
  final String version = A2uiProtocolVersion.v0_9.jsonValue;
  processor.processMessages([
    {
      'version': version,
      'createSurface': {'surfaceId': 's', 'catalogId': exampleCatalog.id},
    },
    if (data != null)
      {
        'version': version,
        'updateDataModel': {'surfaceId': 's', 'value': data},
      },
    {
      'version': version,
      'updateComponents': {
        'surfaceId': 's',
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['pref-1'],
          },
          {'id': 'pref-1', 'component': 'PreferenceRow', ...properties},
        ],
      },
    },
  ]);
  final SurfaceModel<ComponentImplementation> surface = processor.model
      .getSurface('s')!;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: A2uiSurface(surface: surface)),
    ),
  );
  await tester.pumpAndSettle();
  return surface;
}

void main() {
  testWidgets('the switch writes to the path the model bound', (tester) async {
    final surface = await pumpItem(
      tester,
      data: {
        'settings': {'notify': false},
      },
      properties: <String, Object?>{
        'label': 'Weekly summary',
        'enabled': <String, Object?>{'path': '/settings/notify'},
      },
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(surface.dataModel.get('/settings/notify'), isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('a literal still round-trips, through a path of its own', (
    tester,
  ) async {
    final surface = await pumpItem(
      tester,
      properties: <String, Object?>{'label': 'Weekly summary', 'enabled': true},
    );

    // Nothing was bound, so the literal is what the switch starts from.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(surface.dataModel.get('/pref-1.enabled'), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
