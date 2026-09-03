import 'package:genui_gen/genui_gen.dart';

import 'trend.dart';

part 'metric_row.genui.dart';

/// One line of a `MetricsTable`: a named metric with its value and trend.
///
/// This is a plain Dart class, not a widget. `@GenUiData` makes it a shape the
/// model may emit: the generator derives a JSON Schema from this constructor
/// and a decoder that rebuilds the instance from the map the model produced,
/// so a widget can take `List<MetricRow>` instead of parallel lists of
/// scalars.
///
/// The [Trend] enum lives in this same layer and is shared with the
/// `StatTile` widget, which shows that a data class and a widget can use
/// the same enum without redeclaring it.
@GenUiData(
  description:
      'One row of a metrics table: a labelled metric with its current value, '
      'the direction it is moving in and an optional short note explaining '
      'the number.',
)
class MetricRow {
  /// Creates a metric row.
  const MetricRow({
    required this.label,
    required this.value,
    required this.trend,
    this.note,
  });

  /// A short caption naming the metric, e.g. "Monthly revenue".
  final String label;

  /// The current numeric value of the metric.
  final double value;

  /// Whether the metric went up, down or stayed flat.
  final Trend trend;

  /// An optional one-line comment about this row, e.g. "vs. last quarter".
  final String? note;
}
