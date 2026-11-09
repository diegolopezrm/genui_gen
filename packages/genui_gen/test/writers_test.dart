import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'src/surface.dart';

enum Size { small, large }

/// The node and properties the last build of [_switch] saw, so a test can
/// build writers the way the generated builder does.
late ComponentNode<ComponentImplementation> _node;
late ComponentProps _props;

/// A component built the way the generator builds one with a `@GenUiWrites`
/// parameter: the property is read with [genUiWrittenValue], and the writer
/// comes from [genUiValueWriter].
final CatalogItem _switch = CatalogItem(
  name: 'LabeledSwitch',
  schema: S.object(
    properties: {
      'value': CommonSchemas.dynamicString,
      'volume': CommonSchemas.dynamicNumber,
      'size': CommonSchemas.dynamicString,
    },
  ),
  builder: (context, node, props, buildChild) {
    _node = node;
    _props = props;
    return Text(genUiAsString(genUiWrittenValue(node, props, 'value')) ?? '');
  },
);

Future<Rendered> render(
  WidgetTester tester, {
  Map<String, Object?> properties = const {},
  Map<String, Object?>? data,
}) => renderSurface(
  tester,
  items: [_switch],
  data: data,
  components: [
    {'id': 'switch-1', 'component': 'LabeledSwitch', ...properties},
    {
      'id': 'root',
      'component': 'Column',
      'children': ['switch-1'],
    },
  ],
);

void main() {
  testWidgets('writes to the path the model bound the property to', (
    tester,
  ) async {
    final rendered = await render(
      tester,
      properties: {
        'value': {'path': '/form/notify'},
      },
    );
    genUiValueWriter<String>(_node, _props, 'value')('on');

    expect(rendered.surface.dataModel.get('/form/notify'), 'on');
    expect(rendered.errors, isEmpty);
  });

  testWidgets('a literal leaves nowhere to write, so the component owns it', (
    tester,
  ) async {
    final rendered = await render(tester, properties: {'value': 'a literal'});
    expect(find.text('a literal'), findsOneWidget);

    genUiValueWriter<String>(_node, _props, 'value')('typed');
    await tester.pump();

    expect(rendered.surface.dataModel.get('/switch-1.value'), 'typed');
    // And the control shows what it wrote, rather than the literal.
    expect(find.text('typed'), findsOneWidget);
    expect(rendered.errors, isEmpty);
  });

  testWidgets('a missing property is the same case as a literal', (
    tester,
  ) async {
    final rendered = await render(tester);
    genUiValueWriter<num>(_node, _props, 'volume')(7);

    expect(rendered.surface.dataModel.get('/switch-1.volume'), 7);
  });

  testWidgets('an enum is written as its name', (tester) async {
    final rendered = await render(
      tester,
      properties: {
        'size': {'path': '/form/size'},
      },
    );
    genUiValueWriter<Size>(
      _node,
      _props,
      'size',
      encode: (value) => value.name,
    )(Size.large);

    expect(rendered.surface.dataModel.get('/form/size'), 'large');
  });

  testWidgets('the same writer can be called more than once', (tester) async {
    final rendered = await render(
      tester,
      properties: {
        'value': {'path': '/name'},
      },
    );
    final write = genUiValueWriter<String>(_node, _props, 'value');
    write('ada');
    write('grace');

    expect(rendered.surface.dataModel.get('/name'), 'grace');
  });

  testWidgets('genUiWritePath reports where a value would go', (tester) async {
    await render(
      tester,
      properties: {
        'value': {'path': '/a/b'},
        'size': {'path': ''},
      },
    );

    expect(genUiWritePath(_node, _props, 'value'), '/a/b');
    expect(genUiWritePath(_node, _props, 'volume'), 'switch-1.volume');
    // A binding to nothing names no place to write.
    expect(genUiWritePath(_node, _props, 'size'), 'switch-1.size');
  });

  testWidgets('a write the data model refuses is reported, not thrown', (
    tester,
  ) async {
    final rendered = await render(
      tester,
      data: {
        'rows': <Object?>[1, 2],
      },
      properties: {
        'value': {'path': '/rows/label'},
      },
    );

    // `/rows` holds a list, and `label` is not an index into one, so the data
    // model raises rather than inventing a key.
    expect(
      () => genUiValueWriter<String>(_node, _props, 'value')('x'),
      returnsNormally,
    );
    await tester.pump();

    final A2uiRendererError error = rendered.errors.single;
    expect(error.code, 'DATA_ERROR');
    expect(error.message, allOf(contains('switch-1'), contains('/rows/label')));
  });
}
