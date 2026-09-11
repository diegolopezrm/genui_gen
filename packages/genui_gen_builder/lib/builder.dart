/// `build_runner` entry point for `genui_gen_builder`.
///
/// Referenced from `build.yaml`; applications never import this library
/// directly.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/catalog_aggregator.dart';
import 'src/generator.dart';
import 'src/strings.dart';

export 'src/catalog_aggregator.dart' show CatalogAggregatingBuilder;
export 'src/generator.dart' show GenUiDataGenerator, GenUiGenerator;
export 'src/strings.dart' show generatedFileHeader;

/// Creates the builder that turns `@GenUiWidget` and `@GenUiData` classes
/// into `<file>.genui.dart` part files.
Builder genUiGenBuilder(BuilderOptions options) => PartBuilder(
  const [GenUiGenerator(), GenUiDataGenerator()],
  '.genui.dart',
  header: generatedFileHeader,
  options: options,
);

/// Creates the builder that collects every generated `CatalogItem` in the
/// package into a single `lib/genui_catalog.g.dart`.
Builder genUiCatalogBuilder(BuilderOptions options) =>
    const CatalogAggregatingBuilder();
