/// Renders components the way an app does: through a `MessageProcessor` and
/// an `A2uiSurface`, with a2ui_flutter's basic catalog next to the components
/// under test.
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart' as v0_9;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The id of the catalog [renderSurface] builds.
const String testCatalogId = 'dev.dlsoft.test';

/// The id of the surface [renderSurface] creates.
const String testSurfaceId = 's';

/// The protocol version the messages speak.
final String testVersion = A2uiProtocolVersion.v0_9.jsonValue;

/// What [renderSurface] rendered, and what the surface reported since.
typedef Rendered = ({
  MessageProcessor<ComponentImplementation> processor,
  SurfaceModel<ComponentImplementation> surface,
  List<A2uiRendererAction> actions,
  List<A2uiRendererError> errors,
});

/// The basic catalog with [components] and [functions] added.
CatalogImplementation testCatalog({
  List<ComponentImplementation> components = const [],
  List<FunctionImplementation> functions = const [],
}) => v0_9.basicCatalog().derive(
  catalogId: testCatalogId,
  addComponents: components,
  addFunctions: functions,
);

/// Creates surface [testSurfaceId], fills its data model with [data] and
/// gives it [components], in one batch, and pumps it under a `MaterialApp`.
///
/// The processor validates strictly, so a schema mistake in a component under
/// test fails the test rather than rendering nothing.
Future<Rendered> renderSurface(
  WidgetTester tester, {
  required List<Map<String, Object?>> components,
  List<ComponentImplementation> items = const [],
  List<FunctionImplementation> functions = const [],
  Map<String, Object?>? data,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [testCatalog(components: items, functions: functions)],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);
  final actions = <A2uiRendererAction>[];
  final errors = <A2uiRendererError>[];
  processor.model.onAction.subscribe(actions.add);
  processor.model.onError.subscribe(errors.add);
  processor.processMessages([
    {
      'version': testVersion,
      'createSurface': {'surfaceId': testSurfaceId, 'catalogId': testCatalogId},
    },
    if (data != null)
      {
        'version': testVersion,
        'updateDataModel': {
          'surfaceId': testSurfaceId,
          'path': '/',
          'value': data,
        },
      },
    {
      'version': testVersion,
      'updateComponents': {
        'surfaceId': testSurfaceId,
        'components': components,
      },
    },
  ]);
  final SurfaceModel<ComponentImplementation> surface = processor.model
      .getSurface(testSurfaceId)!;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: A2uiSurface(surface: surface)),
      ),
    ),
  );
  return (
    processor: processor,
    surface: surface,
    actions: actions,
    errors: errors,
  );
}
