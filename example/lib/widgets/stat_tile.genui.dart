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
  schema: S.object(
    description:
        'A compact tile that shows one numeric metric (a KPI) with a '
        'label and a trend indicator: up, down or flat. Use it to '
        'summarize a statistic such as revenue, active users or '
        'conversion rate.',
    properties: {
      'label': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description':
            'A short caption naming the metric, e.g. "Monthly revenue".',
      }),
      'value': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description': 'The current numeric value of the metric.',
      }),
      'trend': S.combined(
        description: 'Whether the metric went up, down or stayed flat.',
        anyOf: [
          S.string(enumValues: ['up', 'down', 'flat']),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
      'history': S.combined(
        description:
            'Recent values of the metric, oldest first, drawn as a '
            'sparkline under the number. Leave it out for a tile with no '
            'history.',
        anyOf: [
          S.list(items: S.number()),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
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
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'StatTile', property);
      return fallback;
    }

    return StatTile(
      label:
          genUiAsString(props.value('label')) ?? missing<String>('label', ''),
      value: (genUiAsNum(props.value('value')) ?? missing<num>('value', 0))
          .toDouble(),
      trend:
          Trend.values.asNameMap()[genUiAsString(props.value('trend'))] ??
          missing<Trend>('trend', Trend.values.first),
      history:
          genUiAsNumList(
            props.value('history'),
          )?.map((n) => n.toDouble()).toList() ??
          const <double>[],
    );
  },
);
