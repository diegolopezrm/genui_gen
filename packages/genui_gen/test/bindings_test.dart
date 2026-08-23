import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  late InMemoryDataModel model;
  late DataContext dataContext;

  setUp(() {
    model = InMemoryDataModel();
    dataContext = DataContext(model, DataPath.root);
  });

  tearDown(() {
    model.dispose();
  });

  Widget host(Widget child) =>
      Directionality(textDirection: TextDirection.ltr, child: child);

  testWidgets('calls the builder directly when there are no bindings', (
    tester,
  ) async {
    GenUiValues? received;
    var buildCount = 0;

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {},
          builder: (context, values) {
            buildCount++;
            received = values;
            return const Text('empty');
          },
        ),
      ),
    );

    expect(find.text('empty'), findsOneWidget);
    expect(buildCount, 1);
    expect(received!.keys, isEmpty);
    expect(received!.string('missing'), isNull);
    expect(received!.has('missing'), isFalse);
    expect(find.byType(BoundString), findsNothing);
  });

  testWidgets('resolves literal values of every supported kind', (
    tester,
  ) async {
    late GenUiValues received;

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {
            'title': GenUiBinding.string('Hello'),
            'count': GenUiBinding.number(42),
            'enabled': GenUiBinding.bool(true),
            'tags': GenUiBinding.stringList(['a', 'b']),
            'absent': GenUiBinding.string(null),
          },
          builder: (context, values) {
            received = values;
            return Text(values.string('title')!);
          },
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    expect(received.string('title'), 'Hello');
    expect(received.number('count'), 42);
    expect(received.boolean('enabled'), isTrue);
    expect(received.stringList('tags'), ['a', 'b']);
    expect(received.string('absent'), isNull);
    expect(received.has('absent'), isFalse);
    expect(received.keys, ['title', 'count', 'enabled', 'tags', 'absent']);
  });

  testWidgets('applies the same conversions as the genui Bound* widgets', (
    tester,
  ) async {
    late GenUiValues received;

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {
            'numberAsString': GenUiBinding.string(7),
            'stringAsNumber': GenUiBinding.number('3.5'),
            'stringAsBool': GenUiBinding.bool('TRUE'),
            'numberAsBool': GenUiBinding.bool(0),
            'mixedList': GenUiBinding.stringList(['x', 1, null, true]),
            'notAList': GenUiBinding.stringList('x'),
            'notANumber': GenUiBinding.number('abc'),
          },
          builder: (context, values) {
            received = values;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(received.string('numberAsString'), '7');
    expect(received.number('stringAsNumber'), 3.5);
    expect(received.boolean('stringAsBool'), isTrue);
    expect(received.boolean('numberAsBool'), isFalse);
    expect(received.stringList('mixedList'), ['x', '1', 'true']);
    expect(received.stringList('notAList'), isNull);
    expect(received.number('notANumber'), isNull);
  });

  testWidgets('composes one genui Bound* widget per binding', (tester) async {
    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {
            'a': GenUiBinding.string('a'),
            'b': GenUiBinding.number(1),
            'c': GenUiBinding.bool(true),
            'd': GenUiBinding.stringList(['d']),
          },
          builder: (context, values) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(BoundString), findsOneWidget);
    expect(find.byType(BoundNumber), findsOneWidget);
    expect(find.byType(BoundBool), findsOneWidget);
    expect(find.byType(BoundList), findsOneWidget);
  });

  testWidgets('resolves {"path": ...} bindings against the data model', (
    tester,
  ) async {
    model.update(DataPath('/product/title'), 'Bound title');
    model.update(DataPath('/product/price'), 12.5);
    model.update(DataPath('/product/inStock'), true);
    model.update(DataPath('/product/tags'), ['new', 'sale']);

    late GenUiValues received;

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {
            'title': GenUiBinding.string({'path': '/product/title'}),
            'price': GenUiBinding.number({'path': '/product/price'}),
            'inStock': GenUiBinding.bool({'path': '/product/inStock'}),
            'tags': GenUiBinding.stringList({'path': '/product/tags'}),
            'missing': GenUiBinding.string({'path': '/product/missing'}),
          },
          builder: (context, values) {
            received = values;
            return Text(values.string('title') ?? '');
          },
        ),
      ),
    );

    expect(find.text('Bound title'), findsOneWidget);
    expect(received.number('price'), 12.5);
    expect(received.boolean('inStock'), isTrue);
    expect(received.stringList('tags'), ['new', 'sale']);
    expect(received.string('missing'), isNull);
  });

  testWidgets('resolves relative paths against the context path', (
    tester,
  ) async {
    model.update(DataPath('/items/0/label'), 'First');
    final DataContext nested = dataContext.nested(DataPath('items/0'));

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: nested,
          bindings: const {
            'label': GenUiBinding.string({'path': 'label'}),
          },
          builder: (context, values) => Text(values.string('label') ?? ''),
        ),
      ),
    );

    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('rebuilds when a bound value changes in the model', (
    tester,
  ) async {
    model.update(DataPath('/counter'), 1);
    model.update(DataPath('/label'), 'one');
    final List<String> seen = <String>[];

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: dataContext,
          bindings: const {
            'counter': GenUiBinding.number({'path': '/counter'}),
            'label': GenUiBinding.string({'path': '/label'}),
            'constant': GenUiBinding.string('fixed'),
          },
          builder: (context, values) {
            final String text =
                '${values.string('label')}:${values.number('counter')}'
                ':${values.string('constant')}';
            seen.add(text);
            return Text(text);
          },
        ),
      ),
    );

    expect(find.text('one:1:fixed'), findsOneWidget);

    model.update(DataPath('/counter'), 2);
    await tester.pump();
    expect(find.text('one:2:fixed'), findsOneWidget);

    model.update(DataPath('/label'), 'two');
    await tester.pump();
    expect(find.text('two:2:fixed'), findsOneWidget);

    expect(seen, ['one:1:fixed', 'one:2:fixed', 'two:2:fixed']);
  });

  testWidgets('re-resolves when the binding definition changes', (
    tester,
  ) async {
    model.update(DataPath('/a'), 'from a');
    model.update(DataPath('/b'), 'from b');

    Widget build(Object? raw) => host(
      GenUiBindings(
        dataContext: dataContext,
        bindings: {'value': GenUiBinding.string(raw)},
        builder: (context, values) => Text(values.string('value') ?? ''),
      ),
    );

    await tester.pumpWidget(build(const {'path': '/a'}));
    expect(find.text('from a'), findsOneWidget);

    await tester.pumpWidget(build(const {'path': '/b'}));
    expect(find.text('from b'), findsOneWidget);

    await tester.pumpWidget(build('literal'));
    expect(find.text('literal'), findsOneWidget);
  });

  testWidgets('resolves {"call": ...} bindings through client functions', (
    tester,
  ) async {
    final DataContext withFunctions = DataContext(
      model,
      DataPath.root,
      functions: const [_UpperCase()],
    );
    model.update(DataPath('/name'), 'ada');

    await tester.pumpWidget(
      host(
        GenUiBindings(
          dataContext: withFunctions,
          bindings: const {
            'shout': GenUiBinding.string({
              'call': 'upperCase',
              'args': {
                'value': {'path': '/name'},
              },
            }),
          },
          builder: (context, values) => Text(values.string('shout') ?? '-'),
        ),
      ),
    );

    // The function call resolves through a stream, so it needs a frame.
    await tester.pump();
    expect(find.text('ADA'), findsOneWidget);

    model.update(DataPath('/name'), 'grace');
    await tester.pump();
    await tester.pump();
    expect(find.text('GRACE'), findsOneWidget);
  });

  test('GenUiValues exposes raw values and typed accessors', () {
    const values = GenUiValues({
      's': 'text',
      'n': 1,
      'b': false,
      'l': ['x'],
      'nil': null,
    });

    expect(values['s'], 'text');
    expect(values.string('s'), 'text');
    expect(values.number('n'), 1);
    expect(values.boolean('b'), isFalse);
    expect(values.stringList('l'), ['x']);
    expect(values.has('nil'), isFalse);
    expect(values.has('b'), isTrue);
    expect(values.keys, ['s', 'n', 'b', 'l', 'nil']);
    expect(GenUiValues.empty.keys, isEmpty);
    expect(values.toString(), contains('text'));
  });

  test('GenUiBinding factories are const and expose the raw value', () {
    const GenUiBinding binding = GenUiBinding.number({'path': '/x'});
    expect(binding.raw, {'path': '/x'});
    expect(const GenUiBinding.string('a').raw, 'a');
    expect(const GenUiBinding.bool(true).raw, isTrue);
    expect(const GenUiBinding.stringList(['a']).raw, ['a']);
  });
}

class _UpperCase extends SynchronousClientFunction {
  const _UpperCase();

  @override
  String get name => 'upperCase';

  @override
  String get description => 'Upper-cases a string.';

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.any;

  @override
  Schema get argumentSchema => S.object(properties: {'value': S.string()});

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) =>
      args['value']?.toString().toUpperCase();
}
