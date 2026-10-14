// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'stat_tile.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [ComponentImplementation] for [StatTile].
final ComponentImplementation statTileCatalogItem = ComponentImplementation(
  name: 'StatTile',
  schema: GenUiSchemas.component(
    description:
        'A compact tile that shows one numeric metric (a KPI) with a '
        'label and a trend indicator: up, down or flat. Use it to '
        'summarize a statistic such as revenue, active users or '
        'conversion rate.',
    properties: {
      'label': GenUiSchemas.string(
        description:
            'A short caption naming the metric, e.g. "Monthly revenue".',
      ),
      'value': GenUiSchemas.number(
        description: 'The current numeric value of the metric.',
      ),
      'trend': GenUiSchemas.string(
        description: 'Whether the metric went up, down or stayed flat.',
        enumValues: ['up', 'down', 'flat'],
      ),
      'history': GenUiSchemas.list(
        description:
            'Recent values of the metric, oldest first, drawn as a '
            'sparkline under the number. Leave it out for a tile with no '
            'history.',
        items: S.number(),
      ),
    },
    required: ['label', 'value', 'trend'],
  ),
  builder: (context, node, props, buildChild) => StatTile(
    label: props.string('label') ?? '',
    value: props.number('value') ?? 0,
    trend:
        Trend.values.asNameMap()[props.string('trend')] ?? Trend.values.first,
    history:
        genUiAsNumList(
          props.value('history'),
        )?.map((n) => n.toDouble()).toList() ??
        const <double>[],
  ),
);
