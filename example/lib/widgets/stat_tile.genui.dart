// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'stat_tile.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [StatTile].
final CatalogItem statTileCatalogItem = CatalogItem(
  name: 'StatTile',
  dataSchema: S.object(
    description:
        'A compact tile that shows one numeric metric (a KPI) with a '
        'label and a trend indicator: up, down or flat. Use it to '
        'summarize a statistic such as revenue, active users or '
        'conversion rate.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description:
            'A short caption naming the metric, e.g. "Monthly revenue".',
      ),
      'value': A2uiSchemas.numberReference(
        description: 'The current numeric value of the metric.',
      ),
      'trend': A2uiSchemas.stringReference(
        description: 'Whether the metric went up, down or stayed flat.',
        enumValues: ['up', 'down', 'flat'],
      ),
    },
    required: ['label', 'value', 'trend'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "StatTile",
    "label": "Sample label",
    "value": 42.5,
    "trend": "up"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'StatTile', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'value': GenUiBinding.number(data['value']),
        'trend': GenUiBinding.string(data['trend']),
      },
      builder: (context, v) => StatTile(
        label: v.string('label') ?? missing<String>('label', ''),
        value: (v.number('value') ?? missing<num>('value', 0)).toDouble(),
        trend:
            Trend.values.asNameMap()[v.string('trend')] ??
            missing<Trend>('trend', Trend.values.first),
      ),
    );
  },
);
