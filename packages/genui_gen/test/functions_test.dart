import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'support/surface.dart';

/// A catalog function of the kind an app would add: it computes something the
/// data model does not hold.
final FunctionImplementation initials = GenUiClientFunction(
  name: 'initials',
  description: 'Returns the initials of a full name.',
  argumentSchema: S.object(
    properties: {'name': GenUiSchemas.string(description: 'A full name.')},
    required: ['name'],
  ),
  returnType: A2uiReturnType.string,
  body: (args, context) {
    final String name = genUiAsString(args['name']) ?? '';
    return name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
  },
);

/// A text component whose `text` calls [function] with [args].
Map<String, Object?> _textCalling(
  String function,
  Map<String, Object?> args, {
  String id = 'root',
}) => {
  'id': id,
  'component': 'Text',
  'text': {'call': function, 'args': args, 'returnType': 'string'},
};

/// Delivers what a future or a stream sent, then renders it.
///
/// The answer arrives in a microtask, after `pump` has decided whether there
/// is a frame to draw, so the frame it schedules is the next one.
Future<void> _deliver(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a function answers a {"call": ...} property', (tester) async {
    final surface = await TestSurface.pump(
      tester,
      testCatalog(functions: [initials]),
      [
        _textCalling('initials', {
          'name': {'path': '/user/name'},
        }),
      ],
      initialData: {
        'user': {'name': 'Ada Lovelace'},
      },
    );
    expect(find.text('AL'), findsOneWidget);

    await surface.send([data('Grace Hopper', path: '/user/name')]);
    expect(find.text('GH'), findsOneWidget);
  });

  group('an async function', () {
    late Map<String, Completer<Object?>> pending;
    late List<String> calls;

    FunctionImplementation lookup() => GenUiClientFunction.async(
      name: 'lookup',
      description: 'Looks a code up.',
      argumentSchema: S.object(
        properties: {'code': GenUiSchemas.string()},
        required: ['code'],
      ),
      returnType: A2uiReturnType.string,
      body: (args, context) {
        final code = args['code']! as String;
        calls.add(code);
        return (pending[code] = Completer<Object?>()).future;
      },
    );

    setUp(() {
      pending = {};
      calls = [];
    });

    testWidgets('answers once its future completes, without being called '
        'again', (tester) async {
      await TestSurface.pump(tester, testCatalog(functions: [lookup()]), [
        _textCalling('lookup', {'code': 'CO'}),
      ]);
      expect(find.text('Colombia'), findsNothing);

      pending['CO']!.complete('Colombia');
      await _deliver(tester);
      expect(find.text('Colombia'), findsOneWidget);
      expect(calls, ['CO']);
    });

    testWidgets('shares one answer between equal arguments', (tester) async {
      await TestSurface.pump(tester, testCatalog(functions: [lookup()]), [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        _textCalling('lookup', {'code': 'CO'}, id: 'a'),
        _textCalling('lookup', {'code': 'CO'}, id: 'b'),
      ]);
      pending['CO']!.complete('Colombia');
      await _deliver(tester);
      expect(find.text('Colombia'), findsNWidgets(2));
      expect(calls, ['CO']);
    });

    testWidgets('asks again when its arguments change', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        testCatalog(functions: [lookup()]),
        [
          _textCalling('lookup', {
            'code': {'path': '/code'},
          }),
        ],
        initialData: {'code': 'CO'},
      );
      pending['CO']!.complete('Colombia');
      await _deliver(tester);

      await surface.send([data('PE', path: '/code')]);
      pending['PE']!.complete('Peru');
      await _deliver(tester);
      expect(find.text('Peru'), findsOneWidget);
      expect(calls, ['CO', 'PE']);
    });

    testWidgets('reports a failure on the surface, and asks again later', (
      tester,
    ) async {
      final surface = await TestSurface.pump(
        tester,
        testCatalog(functions: [lookup()]),
        [
          _textCalling('lookup', {
            'code': {'path': '/code'},
          }),
        ],
        initialData: {'code': 'XX'},
      );
      pending['XX']!.completeError(StateError('No such code'));
      await _deliver(tester);

      expect(surface.errors, isNotEmpty);
      expect(surface.errors.last.message, contains('No such code'));

      await surface.send([data('CO', path: '/code')]);
      await surface.send([data('XX', path: '/code')]);
      expect(calls, ['XX', 'CO', 'XX']);
    });
  });

  testWidgets('a streaming function shows its latest event', (tester) async {
    final controller = StreamController<Object?>();
    addTearDown(controller.close);
    var listens = 0;
    final FunctionImplementation clock = GenUiClientFunction.streaming(
      name: 'clock',
      description: 'The time, as it changes.',
      argumentSchema: S.object(properties: {}),
      returnType: A2uiReturnType.string,
      body: (args, context) {
        listens++;
        return controller.stream;
      },
    );
    await TestSurface.pump(tester, testCatalog(functions: [clock]), [
      _textCalling('clock', {}),
    ]);

    controller.add('09:00');
    await _deliver(tester);
    expect(find.text('09:00'), findsOneWidget);

    controller.add('09:01');
    await _deliver(tester);
    expect(find.text('09:01'), findsOneWidget);
    expect(listens, 1);
  });

  test('a function reaches the exported catalog document', () {
    final json = genUiCatalogJson(testCatalog(functions: [initials]));
    final functions = json['functions']! as Map<String, Object?>;
    expect(functions.keys, contains('initials'));
  });
}
