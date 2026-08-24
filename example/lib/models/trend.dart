/// The direction a metric is moving in.
///
/// Shared by the `StatTile` widget and the `MetricRow` data class, which shows
/// that a `@GenUiWidget` property and a `@GenUiData` field can be the same
/// enum without redeclaring it. The generator maps it to a string schema with
/// `enumValues` in both places.
enum Trend {
  /// The value increased since the previous period.
  up,

  /// The value decreased since the previous period.
  down,

  /// The value is unchanged.
  flat,
}
