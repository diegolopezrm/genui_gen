# genui_gen example

A small Flutter app that shows `genui_gen` end to end: four ordinary widgets
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

Each `lib/widgets/<name>.dart` declares `part '<name>.genui.dart';`. The part
file holds the generated `final CatalogItem <name>CatalogItem`, and
`lib/main.dart` assembles those four items plus genui's basic catalog into one
`Catalog`.

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
