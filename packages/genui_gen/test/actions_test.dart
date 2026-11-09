import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'src/surface.dart';

/// A component built the way the generator builds one with a `VoidCallback`
/// parameter: the action is declared with the common `Action` type and read
/// back through `props.action`.
final CatalogItem _tapCard = CatalogItem(
  name: 'TapCard',
  schema: S.object(properties: {'onTap': CommonSchemas.action}),
  builder: (context, node, props, buildChild) => ElevatedButton(
    onPressed: genUiActionHandler(props.action('onTap')),
    child: const Text('Tap'),
  ),
);

Map<String, Object?> _card(Object? onTap) => <String, Object?>{
  'id': 'root',
  'component': 'TapCard',
  'onTap': ?onTap,
};

void main() {
  test('returns null when there is no action', () {
    expect(genUiActionHandler(null), isNull);
  });

  testWidgets('an omitted action leaves the widget disabled', (tester) async {
    await renderSurface(tester, items: [_tapCard], components: [_card(null)]);

    final ElevatedButton button = tester.widget(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('dispatches the action with its name and source component', (
    tester,
  ) async {
    final rendered = await renderSurface(
      tester,
      items: [_tapCard],
      components: [
        _card({
          'event': {'name': 'product_selected'},
        }),
      ],
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(rendered.errors, isEmpty);
    final A2uiRendererAction action = rendered.actions.single;
    expect(action.name, 'product_selected');
    expect(action.sourceComponentId, 'root');
    expect(action.surfaceId, testSurfaceId);
    expect(action.context, isEmpty);
  });

  testWidgets('resolves the event context against the data model', (
    tester,
  ) async {
    final rendered = await renderSurface(
      tester,
      items: [_tapCard],
      data: {
        'product': {'id': 'sku-42'},
      },
      components: [
        _card({
          'event': {
            'name': 'add_to_cart',
            'context': {
              'productId': {'path': '/product/id'},
              'quantity': 2,
            },
          },
        }),
      ],
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(rendered.errors, isEmpty);
    final A2uiRendererAction action = rendered.actions.single;
    expect(action.name, 'add_to_cart');
    expect(action.context, {'productId': 'sku-42', 'quantity': 2});
  });

  testWidgets('runs a functionCall through the catalog', (tester) async {
    final calls = <Map<String, Object?>>[];
    final rendered = await renderSurface(
      tester,
      items: [_tapCard],
      functions: [
        GenUiClientFunction(
          name: 'record',
          description: 'Records its arguments.',
          argumentSchema: S.object(properties: {'item': S.string()}),
          body: (args, context) {
            calls.add(Map<String, Object?>.of(args));
            return null;
          },
        ),
      ],
      components: [
        _card({
          'functionCall': {
            'call': 'record',
            'args': {'item': 'tea'},
          },
        }),
      ],
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(rendered.errors, isEmpty);
    // A function call runs on the client; nothing goes to the agent.
    expect(rendered.actions, isEmpty);
    expect(calls, [
      {'item': 'tea'},
    ]);
  });

  testWidgets('a function that fails is reported, not thrown', (tester) async {
    final rendered = await renderSurface(
      tester,
      items: [_tapCard],
      functions: [
        GenUiClientFunction(
          name: 'explode',
          description: 'Always fails.',
          argumentSchema: S.object(properties: {}),
          body: (args, context) => throw StateError('boom'),
        ),
      ],
      components: [
        _card({
          'functionCall': {'call': 'explode'},
        }),
      ],
    );

    await tester.tap(find.text('Tap'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(rendered.actions, isEmpty);
    final A2uiRendererError error = rendered.errors.single;
    expect(error.code, 'EXECUTION_ERROR');
    expect(error.message, contains('explode'));
  });

  testWidgets('a malformed action is refused before the widget sees it', (
    tester,
  ) async {
    // The renderer checks the component against its schema, which declares
    // the common `Action` type, so an event without a name never reaches the
    // handler: the message is rejected and the agent told why.
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [
        testCatalog(components: [_tapCard]),
      ],
      reportErrorsOnly: true,
    );
    addTearDown(processor.dispose);

    final List<ErrorMessage> rejected = processor.processMessagesWithErrors([
      {
        'version': testVersion,
        'createSurface': {
          'surfaceId': testSurfaceId,
          'catalogId': testCatalogId,
        },
      },
      {
        'version': testVersion,
        'updateComponents': {
          'surfaceId': testSurfaceId,
          'components': [
            _card({'event': <String, Object?>{}}),
          ],
        },
      },
    ]);

    expect(rejected, hasLength(1));
    expect(
      processor.model.getSurface(testSurfaceId)!.componentsModel.get('root'),
      isNull,
    );
  });
}
