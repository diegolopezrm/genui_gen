import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

enum Size { small, large }

/// Pumps a widget that builds a [CatalogItemContext] with a real
/// [BuildContext] and hands it to [body].
Future<void> pumpWithContext(
  WidgetTester tester, {
  required DataContext dataContext,
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
              id: 'switch-1',
              type: 'LabeledSwitch',
              buildChild: (_, [_]) => const SizedBox.shrink(),
              dispatchEvent: (_) {},
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
  late List<Object> errors;

  setUp(() {
    model = InMemoryDataModel();
    dataContext = DataContext(model, DataPath.root);
    errors = <Object>[];
  });

  tearDown(() {
    model.dispose();
  });

  Future<CatalogItemContext> contextWith(
    WidgetTester tester, {
    Object data = const <String, Object?>{},
  }) async {
    late CatalogItemContext captured;
    await pumpWithContext(
      tester,
      dataContext: dataContext,
      reportError: (error, _) => errors.add(error),
      data: data,
      body: (ctx) {
        captured = ctx;
        return const SizedBox.shrink();
      },
    );
    return captured;
  }

  testWidgets('writes to the path the model bound the property to', (
    tester,
  ) async {
    final ctx = await contextWith(tester);
    genUiValueWriter<bool>(ctx, {'path': '/form/notify'}, 'value')(true);

    expect(model.getValue<bool>(DataPath('/form/notify')), isTrue);
    expect(errors, isEmpty);
  });

  testWidgets('a literal leaves nowhere to write, so the component owns it', (
    tester,
  ) async {
    final ctx = await contextWith(tester);
    genUiValueWriter<String>(ctx, 'a literal', 'value')('typed');

    expect(model.getValue<String>(DataPath('switch-1.value')), 'typed');
    expect(errors, isEmpty);
  });

  testWidgets('a missing property is the same case as a literal', (
    tester,
  ) async {
    final ctx = await contextWith(tester);
    genUiValueWriter<num>(ctx, null, 'volume')(7);

    expect(model.getValue<num>(DataPath('switch-1.volume')), 7);
  });

  testWidgets('a path that is not a string is not a binding', (tester) async {
    final ctx = await contextWith(tester);
    genUiValueWriter<num>(ctx, {'path': 42}, 'volume')(7);

    expect(model.getValue<num>(DataPath('switch-1.volume')), 7);
  });

  testWidgets('an enum is written as its name', (tester) async {
    final ctx = await contextWith(tester);
    genUiValueWriter<Size>(
      ctx,
      {'path': '/form/size'},
      'size',
      encode: (value) => value.name,
    )(Size.large);

    expect(model.getValue<String>(DataPath('/form/size')), 'large');
  });

  testWidgets('the same writer can be called more than once', (tester) async {
    final ctx = await contextWith(tester);
    final write = genUiValueWriter<String>(ctx, {'path': '/name'}, 'value');
    write('ada');
    write('grace');

    expect(model.getValue<String>(DataPath('/name')), 'grace');
  });

  testWidgets('genUiWritePath reports where a value would go', (tester) async {
    final ctx = await contextWith(tester);

    expect(genUiWritePath(ctx, {'path': '/a/b'}, 'value'), '/a/b');
    expect(genUiWritePath(ctx, 'literal', 'value'), 'switch-1.value');
    expect(genUiWritePath(ctx, {'path': ''}, 'value'), 'switch-1.value');
  });

  testWidgets('a write the data model refuses is reported, not thrown', (
    tester,
  ) async {
    model.update(DataPath('/rows'), <Object?>[1, 2]);
    final ctx = await contextWith(tester);

    // `/rows` holds a list, and `label` is not an index into one, so the data
    // model raises rather than inventing a key.
    expect(
      () =>
          genUiValueWriter<String>(ctx, {'path': '/rows/label'}, 'value')('x'),
      returnsNormally,
    );
    expect(errors, hasLength(1));
    // The data model's own exception comes from `a2ui_core`, which this
    // package does not depend on, so it arrives wrapped with its message kept.
    expect(errors.single, isA<A2uiValidationException>());
    expect(
      errors.single.toString(),
      allOf(
        contains('switch-1'),
        contains('/rows/label'),
        contains('non-numeric segment'),
      ),
    );
  });
}
