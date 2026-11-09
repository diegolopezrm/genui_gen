import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'src/surface.dart';

/// The rules an agent would send with a component.
List<Object?> rules() => <Object?>[
  {
    'condition': {
      'call': 'required',
      'args': {
        'value': {'path': '/form/email'},
      },
    },
    'message': 'We need an email to reach you.',
  },
  {
    'condition': {'path': '/form/agreed'},
    'message': 'You have to accept the terms.',
  },
];

/// A component built the way the generator builds one with a `@GenUiChecked`
/// parameter: `checks` is declared as a list of `CheckRule`s, and the result
/// is read back with [GenUiCheckResult.of].
final CatalogItem _field = CatalogItem(
  name: 'Field',
  schema: S.object(
    properties: {
      'checks': S.list(
        description: 'Validation rules for this component.',
        items: CommonSchemas.checkRule,
      ),
    },
  ),
  builder: (context, node, props, buildChild) {
    final checked = GenUiCheckResult.of(props);
    return Text(checked.message ?? 'ok');
  },
);

Future<Rendered> render(
  WidgetTester tester, {
  required Map<String, Object?> form,
  Object? checks,
}) async {
  final rendered = await renderSurface(
    tester,
    items: [_field],
    data: {'form': form},
    components: [
      {'id': 'root', 'component': 'Field', 'checks': ?checks},
    ],
  );
  await tester.pumpAndSettle();
  return rendered;
}

void main() {
  testWidgets('the first failing rule is the one that speaks', (tester) async {
    await render(tester, form: {'email': ''}, checks: rules());

    // Both rules fail on an empty value; the agent listed `required` first.
    expect(find.text('We need an email to reach you.'), findsOneWidget);
  });

  testWidgets('a later rule speaks once the earlier one passes', (
    tester,
  ) async {
    await render(
      tester,
      form: {'email': 'diego@example.com', 'agreed': false},
      checks: rules(),
    );

    expect(find.text('You have to accept the terms.'), findsOneWidget);
  });

  testWidgets('a valid value says nothing', (tester) async {
    await render(
      tester,
      form: {'email': 'diego@example.com', 'agreed': true},
      checks: rules(),
    );

    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('the message follows the data model as the user types', (
    tester,
  ) async {
    final rendered = await render(
      tester,
      form: {'email': '', 'agreed': true},
      checks: rules(),
    );
    expect(find.text('We need an email to reach you.'), findsOneWidget);

    rendered.surface.dataModel.set('/form/email', 'diego@example.com');
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('no checks at all is valid', (tester) async {
    await render(tester, form: {});
    expect(find.text('ok'), findsOneWidget);
  });

  test('a result reads the same as one built by hand', () {
    expect(
      GenUiCheckResult.valid,
      const GenUiCheckResult(isValid: true, message: null),
    );
    expect(
      const GenUiCheckResult(isValid: false, message: 'No.').toString(),
      'invalid: No.',
    );
  });

  test('a rule with no message is refused before it reaches the widget', () {
    // A2UI requires the message, and the renderer checks the component
    // against its schema, so the agent is told rather than the person seeing
    // an unexplained red field.
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [
        testCatalog(components: [_field]),
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
            {
              'id': 'root',
              'component': 'Field',
              'checks': [
                {'condition': false},
              ],
            },
          ],
        },
      },
    ]);

    expect(rejected, hasLength(1));
  });
}
