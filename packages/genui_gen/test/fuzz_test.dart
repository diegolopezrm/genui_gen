import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

/// A component that casts what the model sent, which is what the fuzzer is
/// for: valid against its own schema, and fatal on anything else.
final CatalogItem fragile = CatalogItem(
  name: 'Fragile',
  dataSchema: S.object(
    description: 'Casts its property instead of coercing it.',
    properties: {'label': A2uiSchemas.stringReference()},
    required: ['label'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "Fragile", "label": "hello"}]',
  ],
  widgetBuilder: (ctx) => _Fragile((ctx.data as JsonMap)['label']),
);

/// The cast happens while the widget builds, which is where a real one
/// happens: genui hands the property over untouched and `Slider`,
/// `TextField` and the rest read it with `as`.
class _Fragile extends StatelessWidget {
  const _Fragile(this.raw);

  final Object? raw;

  @override
  Widget build(BuildContext context) => Text(raw! as String);
}

/// The same component, written the way the generator writes one.
final CatalogItem sturdy = CatalogItem(
  name: 'Sturdy',
  dataSchema: S.object(
    description: 'Coerces its property.',
    properties: {'label': A2uiSchemas.stringReference()},
    required: ['label'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "Sturdy", "label": "hello"}]',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {'label': GenUiBinding.string(data['label'])},
      builder: (context, v) => Text(v.string('label') ?? 'missing'),
    );
  },
);

Catalog catalogOf(List<CatalogItem> items) =>
    Catalog(items, catalogId: 'test.fuzz');

void main() {
  testWidgets('a component that casts is reported, with the case to paste', (
    tester,
  ) async {
    final findings = await genUiFuzz(
      catalog: catalogOf([fragile]),
      pump: tester.pumpWidget,
    );

    expect(findings, isNotEmpty);
    expect(findings.every((f) => f.component == 'Fragile'), isTrue);
    expect(
      findings.any((f) => f.kind == GenUiFuzzKind.threw),
      isTrue,
      reason: 'a cast on a property the schema lets the model fill',
    );
    // The finding carries the exact component, not a description of it.
    final threw = findings.firstWhere((f) => f.kind == GenUiFuzzKind.threw);
    expect(threw.componentJson, contains('"component":"Fragile"'));
    expect(threw.mutation, isNotEmpty);
  });

  testWidgets('a component that coerces is left alone', (tester) async {
    final findings = await genUiFuzz(
      catalog: catalogOf([sturdy]),
      pump: tester.pumpWidget,
    );
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  testWidgets('skip and only decide what runs', (tester) async {
    final both = catalogOf([fragile, sturdy]);

    final skipped = await genUiFuzz(
      catalog: both,
      pump: tester.pumpWidget,
      skip: {'Fragile'},
    );
    expect(skipped, isEmpty);

    final onlyFragile = await genUiFuzz(
      catalog: both,
      pump: tester.pumpWidget,
      only: {'Fragile'},
    );
    expect(onlyFragile, isNotEmpty);
    expect(onlyFragile.every((f) => f.component == 'Fragile'), isTrue);
  });

  testWidgets('the case count per component is bounded and reproducible', (
    tester,
  ) async {
    final first = await genUiFuzz(
      catalog: catalogOf([fragile]),
      pump: tester.pumpWidget,
      maxCasesPerComponent: 3,
    );
    final second = await genUiFuzz(
      catalog: catalogOf([fragile]),
      pump: tester.pumpWidget,
      maxCasesPerComponent: 3,
    );

    expect(first.length, lessThanOrEqualTo(3));
    expect(
      first.map((f) => f.mutation).toList(),
      second.map((f) => f.mutation).toList(),
      reason: 'the same bound has to drop the same tail',
    );
  });

  testWidgets('an empty render is only reported when asked for', (
    tester,
  ) async {
    final off = await genUiFuzz(
      catalog: catalogOf([sturdy]),
      pump: tester.pumpWidget,
    );
    final on = await genUiFuzz(
      catalog: catalogOf([sturdy]),
      pump: tester.pumpWidget,
      reportEmpty: true,
    );
    expect(off.where((f) => f.kind == GenUiFuzzKind.renderedNothing), isEmpty);
    expect(on.length, greaterThanOrEqualTo(off.length));
  });

  testWidgets('a catalog with no id says so instead of guessing', (
    tester,
  ) async {
    expect(
      () => genUiFuzz(catalog: Catalog([sturdy]), pump: tester.pumpWidget),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the summary groups by component', () {
    const finding = GenUiFuzzFinding(
      component: 'Fragile',
      mutation: '`label` as a number',
      kind: GenUiFuzzKind.threw,
      detail: 'not a subtype',
      componentJson: '{}',
    );
    expect(genUiFuzzSummary(const []), 'nothing broke');
    final summary = genUiFuzzSummary(const [finding, finding]);
    expect(summary, contains('2 in 1 component'));
    expect(summary, contains('Fragile'));
  });
}
