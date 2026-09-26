/// `build_runner` entry point for `genui_gen_builder`.
///
/// Referenced from `build.yaml`; applications never import this library
/// directly.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/catalog_aggregator.dart';
import 'src/function_generator.dart';
import 'src/generator.dart';
import 'src/strings.dart';

export 'src/catalog_aggregator.dart' show CatalogAggregatingBuilder;
export 'src/function_generator.dart' show GenUiFunctionGenerator;
export 'src/generator.dart' show GenUiDataGenerator, GenUiGenerator;
export 'src/strings.dart' show generatedFileHeader;

/// Creates the builder that turns `@GenUiWidget` and `@GenUiData` classes,
/// and `@GenUiFunction` functions, into `<file>.genui.dart` part files.
Builder genUiGenBuilder(BuilderOptions options) => PartBuilder(
  const [GenUiGenerator(), GenUiDataGenerator(), GenUiFunctionGenerator()],
  '.genui.dart',
  header: generatedFileHeader,
  options: options,
);

/// Creates the builder that collects every generated `CatalogItem` in the
/// package into a single `lib/genui_catalog.g.dart`.
///
/// Reads the `catalog_id` option, which becomes the id of the emitted
/// `Catalog`.
Builder genUiCatalogBuilder(BuilderOptions options) =>
    CatalogAggregatingBuilder(catalogId: _catalogId(options));

/// The configured `catalog_id`, rejected here rather than emitted as broken
/// Dart if it is not a string.
///
/// A YAML value such as `catalog_id: 2.0` arrives as a double, and quietly
/// stringifying it would write an id nobody chose.
String? _catalogId(BuilderOptions options) {
  final Object? configured = options.config[catalogIdOption];
  if (configured == null) return null;
  if (configured is! String) {
    throw ArgumentError.value(
      configured,
      catalogIdOption,
      'must be a string, such as `com.example.my_catalog`. Quote it in '
          '`build.yaml` if it looks like a number or a boolean',
    );
  }
  return configured;
}
