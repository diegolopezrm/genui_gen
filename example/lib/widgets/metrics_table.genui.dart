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
  dataSchema: S.object(
    description:
        'A titled table of metrics. Each row has a label, a numeric '
        'value, a trend (up, down or flat) and an optional note. Use '
        'it to compare several KPIs at once, for example a quarterly '
        'summary or the health of a set of services.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description:
            'The heading shown above the table, e.g. "Q3 performance".',
      ),
      'rows': A2uiSchemas.listOrReference(
        description: 'The rows of the table, in display order.',
        items: metricRowGenUiSchema,
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
    "title": "Sample title",
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'MetricsTable', property);
      return fallback;
    }

    GenUiMissingFieldReporter missingIn(String property) =>
        (field) => genUiReportMissing(ctx, 'MetricsTable', '$property.$field');
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'rows': GenUiBinding.objectList(data['rows']),
      },
      builder: (context, v) => MetricsTable(
        title: v.string('title') ?? missing<String>('title', ''),
        rows:
            v
                .objectList('rows')
                ?.map((json) => metricRowFromGenUiJson(json, missingIn('rows')))
                .toList() ??
            missing<List<MetricRow>>('rows', const <MetricRow>[]),
      ),
    );
  },
);
