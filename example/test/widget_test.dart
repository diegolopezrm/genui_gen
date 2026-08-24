import 'package:example/main.dart';
import 'package:example/models/metric_row.dart';
import 'package:example/models/trend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

/// Every widget the example annotates, in catalog order.
const generatedItems = <String>[
  'ProductCard',
  'StatTile',
  'TagRow',
  'Panel',
  'MetricsTable',
];

void main() {
  testWidgets('catalog contains every generated item', (tester) async {
    final names = exampleCatalog.items.map((item) => item.name).toSet();
    expect(names, containsAll(generatedItems));
  });

  testWidgets('every generated item has a parseable example', (tester) async {
    for (final name in generatedItems) {
      final item = exampleCatalog.items.singleWhere((i) => i.name == name);
      expect(item.exampleData, isNotEmpty, reason: name);
      for (final example in item.exampleData) {
        expect(example(), contains('"id": "root"'), reason: name);
      }
    }
  });

  test('the generated data schema describes a MetricRow', () {
    final json = metricRowGenUiSchema.value;
    expect(json['type'], 'object');
    expect(json['required'], containsAll(<String>['label', 'value', 'trend']));
    final properties = json['properties'] as Map<String, Object?>;
    expect(properties.keys, containsAll(<String>['label', 'value', 'trend']));
    final trend = properties['trend'] as Map<String, Object?>;
    expect(trend['enum'], <String>['up', 'down', 'flat']);
  });

  test('the generated decoder rebuilds a MetricRow', () {
    final row = metricRowFromGenUiJson(const <String, Object?>{
      'label': 'Revenue',
      'value': 128400,
      'trend': 'up',
      'note': 'vs. last quarter',
    });
    expect(row.label, 'Revenue');
    expect(row.value, 128400.0);
    expect(row.trend, Trend.up);
    expect(row.note, 'vs. last quarter');
  });

  test('the generated decoder falls back on a malformed object', () {
    final row = metricRowFromGenUiJson(const <String, Object?>{});
    expect(row.label, '');
    expect(row.value, 0.0);
    expect(row.trend, Trend.values.first);
    expect(row.note, isNull);
  });

  test('the generated decoder coerces instead of throwing', () {
    // The model sent a String where a number was declared and a number where
    // a String was declared; nothing throws and the values still land.
    final row = metricRowFromGenUiJson(const <String, Object?>{
      'label': 42,
      'value': '128400.5',
      'trend': 'up',
    });
    expect(row.label, '42');
    expect(row.value, 128400.5);
    expect(row.trend, Trend.up);
  });

  test('the generated decoder reports the fields it had to replace', () {
    final reported = <String>[];
    final row = metricRowFromGenUiJson(const <String, Object?>{
      'value': 'not a number',
    }, reported.add);
    expect(row.label, '');
    expect(row.value, 0.0);
    expect(reported, <String>['label', 'value', 'trend']);
  });

  testWidgets('a bound object list reaches the widget as MetricRow', (
    tester,
  ) async {
    final model = InMemoryDataModel();
    addTearDown(model.dispose);
    final captured = <MetricRow>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GenUiBindings(
          dataContext: DataContext(model, DataPath.root),
          bindings: {
            'rows': GenUiBinding.objectList(const <Object?>[
              {'label': 'Revenue', 'value': 10, 'trend': 'up'},
              {'label': 'Churn', 'value': 2, 'trend': 'down'},
            ]),
          },
          builder: (context, v) {
            captured
              ..clear()
              ..addAll(
                v.objectList('rows')?.map(metricRowFromGenUiJson).toList() ??
                    const <MetricRow>[],
              );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(captured, hasLength(2));
    expect(captured.first.label, 'Revenue');
    expect(captured.last.trend, Trend.down);
  });

  testWidgets('the gallery page renders', (tester) async {
    await tester.pumpWidget(const GenUiGenExampleApp());
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('genui_gen example'), findsOneWidget);
  });
}
