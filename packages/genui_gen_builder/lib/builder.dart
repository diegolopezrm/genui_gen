/// `build_runner` entry point for `genui_gen_builder`.
///
/// Referenced from `build.yaml`; applications never import this library
/// directly.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator.dart';

export 'src/generator.dart' show GenUiGenerator;

/// Header written at the top of every generated `.genui.dart` file.
const generatedFileHeader = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file
''';

/// Creates the builder that turns `@GenUiWidget` classes into
/// `<file>.genui.dart` part files.
Builder genUiGenBuilder(BuilderOptions options) => PartBuilder(
  const [GenUiGenerator()],
  '.genui.dart',
  header: generatedFileHeader,
  options: options,
);
