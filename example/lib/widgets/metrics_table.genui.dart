// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'metrics_table.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [ComponentImplementation] for [MetricsTable].
final ComponentImplementation metricsTableCatalogItem = ComponentImplementation(
  name: 'MetricsTable',
  schema: GenUiSchemas.component(
    description:
        'A titled table of metrics. Each row has a label, a numeric '
        'value, a trend (up, down or flat) and an optional note. Use '
        'it to compare several KPIs at once, for example a quarterly '
        'summary or the health of a set of services.',
    properties: {
      'title': GenUiSchemas.string(
        description:
            'The heading shown above the table, e.g. "Q3 performance".',
      ),
      'rows': GenUiSchemas.list(
        description: 'The rows of the table, in display order.',
        items: metricRowGenUiSchema,
      ),
    },
    required: ['title', 'rows'],
  ),
  builder: (context, node, props, buildChild) => MetricsTable(
    title: props.string('title') ?? '',
    rows:
        genUiAsObjectList(props.value('rows'))
            ?.map(
              (json) => metricRowFromGenUiJson(
                json,
                genUiMissingIn(context, node, 'rows'),
              ),
            )
            .toList() ??
        const <MetricRow>[],
  ),
);
