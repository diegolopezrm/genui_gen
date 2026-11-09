// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'metrics_table.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [MetricsTable].
final CatalogItem metricsTableCatalogItem = CatalogItem(
  name: 'MetricsTable',
  schema: S.object(
    description:
        'A titled table of metrics. Each row has a label, a numeric '
        'value, a trend (up, down or flat) and an optional note. Use '
        'it to compare several KPIs at once, for example a quarterly '
        'summary or the health of a set of services.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description':
            'The heading shown above the table, e.g. "Q3 performance".',
      }),
      'rows': S.combined(
        description: 'The rows of the table, in display order.',
        anyOf: [
          S.list(items: metricRowGenUiSchema),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    },
    required: ['title', 'rows'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "MetricsTable",
    "title": "Quarterly report",
    "rows": [
      {
        "label": "Sample label 1",
        "value": 42.5,
        "trend": "up"
      },
      {
        "label": "Sample label 2",
        "value": 43.5,
        "trend": "down"
      }
    ]
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'MetricsTable', property);
      return fallback;
    }

    GenUiMissingFieldReporter missingIn(String property) =>
        (field) => genUiReportMissing(node, 'MetricsTable', '$property.$field');
    return MetricsTable(
      title:
          genUiAsString(props.value('title')) ?? missing<String>('title', ''),
      rows:
          genUiAsObjectList(props.value('rows'))
              ?.map((json) => metricRowFromGenUiJson(json, missingIn('rows')))
              .toList() ??
          missing<List<MetricRow>>('rows', const <MetricRow>[]),
    );
  },
);
