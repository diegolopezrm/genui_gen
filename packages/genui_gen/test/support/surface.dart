import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The id of the surface every test renders.
const String surfaceId = 'main';

/// The id of the catalog every test renders against.
const String catalogId = 'dev.dlsoft.genui_gen.test';

/// A catalog of [components] and [functions], next to the basic ones.
CatalogImplementation testCatalog({
  List<ComponentImplementation> components = const [],
  List<FunctionImplementation> functions = const [],
}) => CatalogImplementation(
  id: catalogId,
  components: [...BasicComponents.all, ...components],
  functions: [...BasicCatalog.v0_9().functions.values, ...functions],
  themeSchema: BasicComponents.api.themeSchema,
);

Map<String, Object?> _message(String kind, Map<String, Object?> body) => {
  'version': 'v0.9',
  kind: {'surfaceId': surfaceId, ...body},
};

/// An `updateComponents` message.
Map<String, Object?> components(List<Map<String, Object?>> components) =>
    _message('updateComponents', {'components': components});

/// An `updateDataModel` message.
Map<String, Object?> data(Object? value, {String path = '/'}) =>
    _message('updateDataModel', {'path': path, 'value': value});

/// One surface, rendered from the messages sent to it.
class TestSurface {
  TestSurface._(this._tester, CatalogImplementation catalog)
    : processor = MessageProcessor<ComponentImplementation>(
        catalogs: [catalog],
        defaultVersion: A2uiProtocolVersion.v0_9,
      );

  final WidgetTester _tester;

  /// The processor the messages go through.
  final MessageProcessor<ComponentImplementation> processor;

  /// The actions the surface dispatched.
  final List<A2uiClientAction> actions = [];

  /// The errors reported on the surface's `onError`.
  final List<A2uiClientError> errors = [];

  /// The surface.
  SurfaceModel<ComponentImplementation> get model =>
      processor.groupModel.getSurface(surfaceId)!;

  /// The data model value at [path].
  Object? read(String path) => model.dataModel.get(path);

  void _process(List<Map<String, Object?>> messages) =>
      processor.processMessages(
        AgentToRendererMessagePayload.fromJson(
          messages,
          protocolVersion: A2uiProtocolVersion.v0_9,
        ),
      );

  /// Processes [messages] and pumps a frame.
  Future<void> send(List<Map<String, Object?>> messages) async {
    _process(messages);
    await _tester.pump();
  }

  /// Creates a surface on [catalog] with [initialData] and [root] and its
  /// [others], and pumps it.
  static Future<TestSurface> pump(
    WidgetTester tester,
    CatalogImplementation catalog,
    List<Map<String, Object?>> parts, {
    Object? initialData,
  }) async {
    final surface = TestSurface._(tester, catalog);
    final SurfaceGroupModel<ComponentImplementation> group =
        surface.processor.groupModel;
    group.onAction.addListener(surface.actions.add);
    group.onSurfaceCreated.addListener(
      (model) => model.onError.addListener(surface.errors.add),
    );
    addTearDown(group.dispose);
    surface._process([
      _message('createSurface', {'catalogId': catalog.id}),
      if (initialData != null) data(initialData),
      components(parts),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: A2uiSurface(surface: surface.model)),
      ),
    );
    return surface;
  }
}
