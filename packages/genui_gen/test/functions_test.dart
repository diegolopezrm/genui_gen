import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'src/surface.dart';

/// A catalog function of the kind an app would add: it computes something the
/// data model does not hold.
final FunctionImplementation initials = GenUiClientFunction(
  name: 'initials',
  description: 'Returns the initials of a full name.',
  // Dynamic, so the agent may bind the argument to a path: the renderer
  // checks a call's arguments against this schema before it resolves them.
  argumentSchema: S.object(
    properties: {'name': CommonSchemas.dynamicString},
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

/// A Text whose text is the answer of [call].
Map<String, Object?> _textOf(String call) => <String, Object?>{
  'id': 'root',
  'component': 'Text',
  'text': {
    'call': call,
    'args': {
      'name': {'path': '/user/name'},
    },
  },
};

/// A button that runs [call] when it is pressed.
List<Map<String, Object?>> _buttonRunning(String call) => [
  {
    'id': 'root',
    'component': 'Button',
    'child': 'label',
    'action': {
      'functionCall': {
        'call': call,
        'args': {
          'name': {'path': '/user/name'},
        },
      },
    },
  },
  {'id': 'label', 'component': 'Text', 'text': 'Go'},
];

const Map<String, Object?> _user = {
  'user': {'name': 'Ada Lovelace'},
};

void main() {
  testWidgets('a generated function answers a {"call": ...} property', (
    tester,
  ) async {
    await renderSurface(
      tester,
      functions: [initials],
      data: _user,
      components: [_textOf('initials')],
    );
    await tester.pumpAndSettle();

    expect(find.text('AL'), findsOneWidget);
  });

  test('the function reaches the exported catalog document', () {
    final catalog = CatalogImplementation(
      id: 'test',
      components: const [],
      functions: [initials],
    );
    final json = genUiCatalogJson(catalog);
    final functions = json['functions'] as Map<String, Object?>?;
    expect(functions, isNotNull);
    expect(functions!.keys, contains('initials'));
  });

  group('an async function', () {
    testWidgets('fills a bound property once it answers', (tester) async {
      final answer = Completer<Object?>();
      var calls = 0;
      await renderSurface(
        tester,
        functions: [
          GenUiClientFunction.async(
            name: 'lookUp',
            description: 'Looks the name up.',
            argumentSchema: S.object(
              properties: {'name': CommonSchemas.dynamicString},
            ),
            body: (args, context) {
              calls++;
              return answer.future;
            },
          ),
        ],
        data: _user,
        components: [_textOf('lookUp')],
      );
      expect(find.text('Countess of Lovelace'), findsNothing);

      answer.complete('Countess of Lovelace');
      await tester.pumpAndSettle();

      expect(find.text('Countess of Lovelace'), findsOneWidget);
      // The renderer asks again when the answer arrives; the same arguments
      // get the same answer rather than a second request.
      expect(calls, 1);
    });

    testWidgets('is awaited from an action', (tester) async {
      final ran = Completer<String>();
      await renderSurface(
        tester,
        functions: [
          GenUiClientFunction.async(
            name: 'save',
            description: 'Saves the name.',
            argumentSchema: S.object(
              properties: {'name': CommonSchemas.dynamicString},
            ),
            body: (args, context) async {
              ran.complete(args['name']! as String);
              return null;
            },
          ),
        ],
        data: _user,
        components: _buttonRunning('save'),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(await ran.future, 'Ada Lovelace');
    });
  });

  group('a streaming function', () {
    testWidgets('a bound property follows its answers', (tester) async {
      final answers = StreamController<Object?>.broadcast();
      addTearDown(answers.close);
      await renderSurface(
        tester,
        functions: [
          GenUiClientFunction.streaming(
            name: 'status',
            description: 'The status of the name.',
            argumentSchema: S.object(
              properties: {'name': CommonSchemas.dynamicString},
            ),
            body: (args, context) => answers.stream,
          ),
        ],
        data: _user,
        components: [_textOf('status')],
      );

      answers.add('online');
      await tester.pumpAndSettle();
      expect(find.text('online'), findsOneWidget);

      answers.add('away');
      await tester.pumpAndSettle();
      expect(find.text('away'), findsOneWidget);
    });

    testWidgets('an action takes its first answer', (tester) async {
      final seen = <Object?>[];
      final rendered = await renderSurface(
        tester,
        functions: [
          GenUiClientFunction.streaming(
            name: 'ping',
            description: 'Answers twice.',
            argumentSchema: S.object(
              properties: {'name': CommonSchemas.dynamicString},
            ),
            body: (args, context) {
              seen.add(args['name']);
              return Stream<Object?>.fromIterable(<Object?>['one', 'two']);
            },
          ),
        ],
        data: _user,
        components: _buttonRunning('ping'),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(seen, ['Ada Lovelace']);
      expect(rendered.errors, isEmpty);
    });
  });
}
