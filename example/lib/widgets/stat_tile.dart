import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../models/trend.dart';

part 'stat_tile.genui.dart';

/// A compact Material tile that shows a single metric with its trend.
@GenUiWidget(
  description:
      'A compact tile that shows one numeric metric (a KPI) with a label and '
      'a trend indicator: up, down or flat. Use it to summarize a statistic '
      'such as revenue, active users or conversion rate.',
)
class StatTile extends StatelessWidget {
  /// Creates a stat tile.
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.trend,
    this.history = const <double>[],
  });

  /// A short caption naming the metric, e.g. "Monthly revenue".
  final String label;

  /// The current numeric value of the metric.
  final double value;

  /// Whether the metric went up, down or stayed flat.
  final Trend trend;

  /// Recent values of the metric, oldest first, drawn as a sparkline under
  /// the number. Leave it out for a tile with no history.
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final (IconData icon, Color color) = switch (trend) {
      Trend.up => (Icons.trending_up, colors.primary),
      Trend.down => (Icons.trending_down, colors.error),
      Trend.flat => (Icons.trending_flat, colors.onSurfaceVariant),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatValue(value),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (history.length > 1) ...[
                    const SizedBox(height: 8),
                    _Sparkline(values: history, color: color),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 32),
          ],
        ),
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

/// A minimal bar sparkline: one bar per value, scaled to the largest.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double peak = values.reduce((a, b) => a > b ? a : b);
    final double floor = values.reduce((a, b) => a < b ? a : b);
    final double span = peak - floor;

    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final double value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: FractionallySizedBox(
                  // A flat series still draws: every bar takes full height
                  // rather than collapsing to nothing.
                  heightFactor: span == 0
                      ? 1
                      : ((value - floor) / span).clamp(0.08, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
