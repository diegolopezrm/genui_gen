# genui_gen example

A small Flutter app that shows `genui_gen` end to end: five ordinary widgets
are annotated with `@GenUiWidget`, `build_runner` derives a genui
`CatalogItem` for each one, and the app renders every generated example with
genui's `DebugCatalogView`. No LLM, API key or network connection is needed.

## The widgets

| File | Demonstrates |
|---|---|
| `lib/widgets/product_card.dart` | required/optional `String`, `double`, a `VoidCallback` action, per-parameter doc comments |
| `lib/widgets/stat_tile.dart` | a Dart `enum` mapped to `enumValues` |
| `lib/widgets/tag_row.dart` | `List<String>` and an `int` with a default value |
| `lib/widgets/panel.dart` | a `Widget` child, a `List<Widget>` with a default, and `@GenUiAction(eventName: 'panel_closed')` |
| `lib/models/trend.dart` | a plain enum shared by a widget property and a `@GenUiData` field |
| `lib/widgets/metrics_table.dart` | structured data: a Material `DataTable` driven by `List<MetricRow>`, where `MetricRow` is the `@GenUiData` class in `lib/models/metric_row.dart` |

`MetricsTable` is the one to look at for 0.2. Its constructor takes a
`List<MetricRow>`, so the model emits real JSON objects:

```json
{
  "id": "root",
  "component": "MetricsTable",
  "title": "Q3 performance",
  "rows": [
    {"label": "Revenue", "value": 128400, "trend": "up", "note": "vs. Q2"},
    {"label": "Churn", "value": 2.4, "trend": "down"}
  ]
}
```

`MetricRow` and the `StatTile` widget share the `Trend` enum declared in
`lib/models/trend.dart`, which shows that a `@GenUiData` field and a
`@GenUiWidget` property can be the same enum without redeclaring it. The
`part 'metric_row.genui.dart';` of `metric_row.dart` holds the generated
schema (`metricRowGenUiSchema`) and decoder (`metricRowFromGenUiJson`) that
`metrics_table.genui.dart` uses.

Each `lib/widgets/<name>.dart` declares `part '<name>.genui.dart';`. The part
file holds the generated `final CatalogItem <name>CatalogItem`, and
`lib/main.dart` assembles those five items plus genui's basic catalog into one
`Catalog`. A `@GenUiData` file such as `lib/models/metric_row.dart` declares
the same kind of `part`, but its generated file holds a schema and a decoder
instead of a `CatalogItem`.

## Run

From the repository root:

```sh
flutter pub get
cd example
flutter run
```

Pick any device or `-d chrome`/`-d macos`. The app lists one card per catalog
item showing its generated example. Tapping a `ProductCard` or the close button
of a `Panel` dispatches the corresponding user action, which the app echoes in
a snack bar.

## Regenerate the catalog items

The `*.genui.dart` files are produced by `genui_gen_builder`. After changing a
widget's constructor, description or doc comments, regenerate them with:

```sh
cd example
dart run build_runner build
```

Or keep them up to date while you edit:

```sh
dart run build_runner watch
```

Never edit the generated files by hand; the next build overwrites them.

## Check

```sh
cd example
flutter analyze
```
