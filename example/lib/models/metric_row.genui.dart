// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'metric_row.dart';

// **************************************************************************
// GenUiDataGenerator
// **************************************************************************

/// Generated schema for [MetricRow].
final ObjectSchema metricRowGenUiSchema = ObjectSchema(
  description:
      'One row of a metrics table: a labelled metric with its '
      'current value, the direction it is moving in and an optional '
      'short note explaining the number.',
  properties: {
    'label': S.string(
      description: 'A short caption naming the metric, e.g. "Monthly revenue".',
    ),
    'value': S.number(description: 'The current numeric value of the metric.'),
    'trend': S.string(
      description: 'Whether the metric went up, down or stayed flat.',
      enumValues: ['up', 'down', 'flat'],
    ),
    'note': S.string(
      description:
          'An optional one-line comment about this row, e.g. "vs. last '
          'quarter".',
    ),
  },
  required: ['label', 'value', 'trend'],
);

/// Decodes a [MetricRow] from the map the model produced.
///
/// Values are coerced the same way genui's `Bound*` widgets coerce a
/// widget property, so a field of the wrong type degrades instead of
/// throwing. Every required field that had to fall back is reported
/// through [onMissing], when one is given.
MetricRow metricRowFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => MetricRow(
  label:
      genUiAsString(json['label']) ??
      genUiMissingField<String>(onMissing, 'label', ''),
  value:
      (genUiAsNum(json['value']) ??
              genUiMissingField<num>(onMissing, 'value', 0))
          .toDouble(),
  trend:
      Trend.values.asNameMap()[genUiAsString(json['trend'])] ??
      genUiMissingField<Trend>(onMissing, 'trend', Trend.values.first),
  note: genUiAsString(json['note']),
);
