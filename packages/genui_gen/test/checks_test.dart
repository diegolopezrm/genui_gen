import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

/// The rules an agent would send with a component.
///
/// Deliberately built from `required` and a bound path rather than from
/// `email`: genui's `EmailFunction` writes its anchor as `\$` inside a raw
/// string, so it rejects every real address and would be testing that bug
/// instead of this widget.
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

Widget harness(DataContext context, Object? checks) => MaterialApp(
  home: Scaffold(
    body: GenUiChecks(
      dataContext: context,
      checks: checks,
      builder: (context, result) =>
          Text(result.message ?? 'ok', textDirection: TextDirection.ltr),
    ),
  ),
);

void main() {
  late InMemoryDataModel model;
  late DataContext context;

  setUp(() {
    model = InMemoryDataModel();
    // The conditions are catalog function calls, so the context has to know
    // the functions the same way a real surface does.
    context = DataContext(
      model,
      DataPath.root,
      functions: BasicCatalogItems.asCatalog().functions,
    );
  });
  tearDown(() => model.dispose);

  testWidgets('the first failing rule is the one that speaks', (tester) async {
    model.update(DataPath('/form/email'), '');
    await tester.pumpWidget(harness(context, rules()));
    await tester.pumpAndSettle();

    // Both rules fail on an empty value; the agent listed `required` first.
    expect(find.text('We need an email to reach you.'), findsOneWidget);
  });

  testWidgets('a later rule speaks once the earlier one passes', (
    tester,
  ) async {
    model.update(DataPath('/form/email'), 'diego@example.com');
    model.update(DataPath('/form/agreed'), false);
    await tester.pumpWidget(harness(context, rules()));
    await tester.pumpAndSettle();

    expect(find.text('You have to accept the terms.'), findsOneWidget);
  });

  testWidgets('a valid value says nothing', (tester) async {
    model.update(DataPath('/form/email'), 'diego@example.com');
    model.update(DataPath('/form/agreed'), true);
    await tester.pumpWidget(harness(context, rules()));
    await tester.pumpAndSettle();

    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('the message follows the data model as the user types', (
    tester,
  ) async {
    model.update(DataPath('/form/email'), '');
    model.update(DataPath('/form/agreed'), true);
    await tester.pumpWidget(harness(context, rules()));
    await tester.pumpAndSettle();
    expect(find.text('We need an email to reach you.'), findsOneWidget);

    model.update(DataPath('/form/email'), 'diego@example.com');
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('no checks at all is valid', (tester) async {
    await tester.pumpWidget(harness(context, null));
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('a rule with no message is skipped, not shown as unexplained', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(context, <Object?>[
        {'condition': false},
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });
}
