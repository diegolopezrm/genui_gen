import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../models/metric_row.dart';
import '../models/trend.dart';

part 'metrics_table.genui.dart';

/// A titled Material table of metrics, one [MetricRow] per line.
///
/// This is the widget `@GenUiData` exists for: its constructor takes a
/// `List<MetricRow>`, so the model emits the rows as structured JSON objects
/// instead of several parallel arrays of scalars that could disagree on
/// length.
@GenUiWidget(
  description:
      'A titled table of metrics. Each row has a label, a numeric value, a '
      'trend (up, down or flat) and an optional note. Use it to compare '
      'several KPIs at once, for example a quarterly summary or the health '
      'of a set of services.',
)
class MetricsTable extends StatelessWidget {
  /// Creates a metrics table.
  const MetricsTable({super.key, required this.title, required this.rows});

  /// The heading shown above the table, e.g. "Q3 performance".
  final String title;

  /// The rows of the table, in display order.
  final List<MetricRow> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No metrics.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 0,
                    ),
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowHeight: 40,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 60,
                      headingRowColor: WidgetStatePropertyAll<Color>(
                        colors.surfaceContainerHighest,
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Metric')),
                        DataColumn(label: Text('Value'), numeric: true),
                        DataColumn(label: Text('Trend')),
                      ],
                      rows: <DataRow>[
                        for (final MetricRow row in rows)
                          DataRow(
                            cells: <DataCell>[
                              DataCell(_MetricLabel(row: row)),
                              DataCell(
                                Text(
                                  _formatValue(row.value),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(_TrendCell(trend: row.trend)),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}

/// The first cell of a row: the metric label with its optional note beneath.
class _MetricLabel extends StatelessWidget {
  const _MetricLabel({required this.row});

  final MetricRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? note = row.note;

    if (note == null || note.isEmpty) {
      return Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The trend cell: a coloured arrow plus the trend name.
class _TrendCell extends StatelessWidget {
  const _TrendCell({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final (IconData icon, Color color, String label) = switch (trend) {
      Trend.up => (Icons.trending_up, colors.primary, 'up'),
      Trend.down => (Icons.trending_down, colors.error, 'down'),
      Trend.flat => (Icons.trending_flat, colors.onSurfaceVariant, 'flat'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
      ],
    );
  }
}
