import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// The surface id the helpers use unless given another.
const String surfaceId = 'main';

/// A v0.9 message of [kind] to [surface].
JsonMap message(String kind, JsonMap body, {String surface = surfaceId}) =>
    <String, Object?>{
      'version': 'v0.9',
      kind: <String, Object?>{'surfaceId': surface, ...body},
    };

/// The `createSurface` message for the example's catalog.
JsonMap createSurface({String surface = surfaceId}) => message(
  'createSurface',
  {'catalogId': exampleCatalog.id},
  surface: surface,
);

/// An `updateComponents` message.
JsonMap components(List<JsonMap> components, {String surface = surfaceId}) =>
    message('updateComponents', {'components': components}, surface: surface);

/// An `updateDataModel` message.
JsonMap data(Object? value, {String path = '/', String surface = surfaceId}) =>
    message('updateDataModel', {
      'path': path,
      'value': value,
    }, surface: surface);

/// A processor over the example's catalog, disposed when the test ends.
MessageProcessor<ComponentImplementation> exampleProcessor() {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [exampleCatalog],
    defaultVersion: A2uiProtocolVersion.v0_9,
  );
  addTearDown(processor.dispose);
  return processor;
}

/// One surface of the example's catalog, rendered from the messages an agent
/// would send it.
class ExampleSurface {
  ExampleSurface._(this._tester, this.processor) {
    processor.groupModel.onAction.addListener(actions.add);
    processor.groupModel.onSurfaceCreated.addListener(
      (surface) => surface.onError.addListener(errors.add),
    );
  }

  final WidgetTester _tester;

  /// The processor the messages go through.
  final MessageProcessor<ComponentImplementation> processor;

  /// The actions the surface dispatched, in order.
  final List<A2uiClientAction> actions = <A2uiClientAction>[];

  /// The errors reported on the surface's `onError`, in order.
  final List<A2uiClientError> errors = <A2uiClientError>[];

  /// The surface.
  SurfaceModel<ComponentImplementation> get model =>
      processor.groupModel.getSurface(surfaceId)!;

  /// The data model value at [path].
  Object? read(String path) => model.dataModel.get(path);

  /// Processes [messages] without pumping a frame.
  void process(List<JsonMap> messages) => processor.processMessages(messages);

  /// Processes [messages] and pumps a frame.
  Future<void> send(List<JsonMap> messages) async {
    process(messages);
    await _tester.pump();
  }

  /// Creates a surface with [parts], seeded with [initialData] when given,
  /// and pumps it in a scrolling Material app.
  static Future<ExampleSurface> pump(
    WidgetTester tester,
    List<JsonMap> parts, {
    Object? initialData,
  }) async {
    final surface = ExampleSurface._(tester, exampleProcessor());
    surface.process([
      createSurface(),
      if (initialData != null) data(initialData),
      components(parts),
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
    await tester.pumpAndSettle();
    return surface;
  }
}
