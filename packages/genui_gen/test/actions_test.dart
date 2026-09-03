import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

/// Pumps a widget that builds a [CatalogItemContext] with a real
/// [BuildContext] and hands it to [body].
Future<void> pumpWithContext(
  WidgetTester tester, {
  required DataContext dataContext,
  required DispatchEventCallback dispatchEvent,
  required void Function(Object error, StackTrace? stack) reportError,
  required Widget Function(CatalogItemContext ctx) body,
  Object data = const <String, Object?>{},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => body(
            CatalogItemContext(
              data: data,
              id: 'card-1',
              type: 'ProductCard',
              buildChild: (_, [_]) => const SizedBox.shrink(),
              dispatchEvent: dispatchEvent,
              buildContext: context,
              dataContext: dataContext,
              getComponent: (_) => null,
              getCatalogItem: (_) => null,
              surfaceId: 'surface-1',
              reportError: reportError,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late InMemoryDataModel model;
  late DataContext dataContext;
  late List<UiEvent> events;
  late List<Object> errors;

  setUp(() {
    model = InMemoryDataModel();
    dataContext = DataContext(model, DataPath.root);
    events = <UiEvent>[];
    errors = <Object>[];
  });

  tearDown(() {
    model.dispose();
  });

  testWidgets('returns null when the action data is null', (tester) async {
    VoidCallback? handler = () {};

    await pumpWithContext(
      tester,
      dataContext: dataContext,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) {
        handler = genUiActionHandler(ctx, null);
        return const SizedBox.shrink();
      },
    );

    expect(handler, isNull);
  });

  testWidgets('dispatches a UserActionEvent with name and sourceComponentId', (
    tester,
  ) async {
    await pumpWithContext(
      tester,
      dataContext: dataContext,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) => ElevatedButton(
        onPressed: genUiActionHandler(ctx, const {
          'event': {'name': 'product_selected'},
        }),
        child: const Text('Tap'),
      ),
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(errors, isEmpty);
    expect(events, hasLength(1));
    final UiEvent event = events.single;
    expect(event.isUserAction, isTrue);
    final UserActionEvent action = UserActionEvent.fromMap(event.toMap());
    expect(action.name, 'product_selected');
    expect(action.sourceComponentId, 'card-1');
    expect(action.context, isEmpty);
  });

  testWidgets('resolves the event context against the data model', (
    tester,
  ) async {
    model.update(DataPath('/product/id'), 'sku-42');

    await pumpWithContext(
      tester,
      dataContext: dataContext,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) => ElevatedButton(
        onPressed: genUiActionHandler(ctx, const {
          'event': {
            'name': 'add_to_cart',
            'context': {
              'productId': {'path': '/product/id'},
              'quantity': 2,
            },
          },
        }),
        child: const Text('Add'),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(errors, isEmpty);
    expect(events, hasLength(1));
    final UserActionEvent action = UserActionEvent.fromMap(
      events.single.toMap(),
    );
    expect(action.name, 'add_to_cart');
    expect(action.sourceComponentId, 'card-1');
    expect(action.context, {'productId': 'sku-42', 'quantity': 2});
  });

  testWidgets('runs a functionCall through the data context', (tester) async {
    final List<JsonMap> calls = <JsonMap>[];
    final DataContext withFunctions = DataContext(
      model,
      DataPath.root,
      functions: [_RecordingFunction(calls)],
    );
    model.update(DataPath('/name'), 'ada');

    await pumpWithContext(
      tester,
      dataContext: withFunctions,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) => ElevatedButton(
        onPressed: genUiActionHandler(ctx, const {
          'functionCall': {
            'call': 'record',
            'args': {
              'who': {'path': '/name'},
            },
          },
        }),
        child: const Text('Call'),
      ),
    );

    await tester.tap(find.text('Call'));
    await tester.pump();

    expect(errors, isEmpty);
    expect(events, isEmpty);
    expect(calls, [
      {'who': 'ada'},
    ]);
  });

  testWidgets('reports A2uiFunctionException when the function fails', (
    tester,
  ) async {
    final DataContext withFunctions = DataContext(
      model,
      DataPath.root,
      functions: const [_FailingFunction()],
    );

    await pumpWithContext(
      tester,
      dataContext: withFunctions,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) => ElevatedButton(
        onPressed: genUiActionHandler(ctx, const {
          'functionCall': {'call': 'explode'},
        }),
        child: const Text('Boom'),
      ),
    );

    await tester.tap(find.text('Boom'));
    await tester.pump();

    expect(events, isEmpty);
    expect(errors, hasLength(1));
    final Object error = errors.single;
    expect(error, isA<A2uiFunctionException>());
    expect((error as A2uiFunctionException).functionName, 'explode');
    expect(error.cause, isA<StateError>());
  });

  testWidgets('closeModal pops the current route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => Builder(
                  builder: (innerContext) => ElevatedButton(
                    onPressed: genUiActionHandler(
                      CatalogItemContext(
                        data: const <String, Object?>{},
                        id: 'close',
                        type: 'Button',
                        buildChild: (_, [_]) => const SizedBox.shrink(),
                        dispatchEvent: events.add,
                        buildContext: innerContext,
                        dataContext: dataContext,
                        getComponent: (_) => null,
                        getCatalogItem: (_) => null,
                        surfaceId: 'surface-1',
                        reportError: (error, _) => errors.add(error),
                      ),
                      const {
                        'functionCall': {'call': 'closeModal'},
                      },
                    ),
                    child: const Text('Close'),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('reports malformed action data instead of throwing', (
    tester,
  ) async {
    late VoidCallback notAMap;
    late VoidCallback eventWithoutName;
    late VoidCallback functionCallWithoutCall;
    late VoidCallback neitherKey;

    await pumpWithContext(
      tester,
      dataContext: dataContext,
      dispatchEvent: events.add,
      reportError: (error, _) => errors.add(error),
      body: (ctx) {
        notAMap = genUiActionHandler(ctx, 'tap')!;
        eventWithoutName = genUiActionHandler(ctx, const {
          'event': {'context': {}},
        })!;
        functionCallWithoutCall = genUiActionHandler(ctx, const {
          'functionCall': {'args': {}},
        })!;
        neitherKey = genUiActionHandler(ctx, const {'other': true})!;
        return const SizedBox.shrink();
      },
    );

    expect(notAMap, returnsNormally);
    expect(eventWithoutName, returnsNormally);
    expect(functionCallWithoutCall, returnsNormally);
    expect(neitherKey, returnsNormally);
    await tester.pump();

    expect(events, isEmpty);
    // The action without "event" or "functionCall" is only logged, like in
    // the core Button; the other three are reported.
    expect(errors, hasLength(3));
    expect(
      errors,
      everyElement(
        isA<A2uiValidationException>()
            .having((e) => e.surfaceId, 'surfaceId', 'surface-1')
            .having((e) => e.path, 'path', 'card-1'),
      ),
    );
  });

  testWidgets('does not throw when reportError itself throws', (tester) async {
    late VoidCallback handler;

    await pumpWithContext(
      tester,
      dataContext: dataContext,
      dispatchEvent: events.add,
      reportError: (error, _) => throw StateError('reporting failed'),
      body: (ctx) {
        handler = genUiActionHandler(ctx, 'malformed')!;
        return const SizedBox.shrink();
      },
    );

    expect(handler, returnsNormally);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _RecordingFunction extends SynchronousClientFunction {
  const _RecordingFunction(this.calls);

  final List<JsonMap> calls;

  @override
  String get name => 'record';

  @override
  String get description => 'Records its arguments.';

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.any;

  @override
  Schema get argumentSchema => S.object(properties: {'who': S.string()});

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    calls.add(Map<String, Object?>.of(args));
    return null;
  }
}

class _FailingFunction extends SynchronousClientFunction {
  const _FailingFunction();

  @override
  String get name => 'explode';

  @override
  String get description => 'Always fails.';

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.any;

  @override
  Schema get argumentSchema => S.object();

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) =>
      throw StateError('kaboom');
}
