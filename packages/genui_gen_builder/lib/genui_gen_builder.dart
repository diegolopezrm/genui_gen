/// Build-time generator for `genui_gen`.
///
/// You normally do not import this library: add `genui_gen_builder` to
/// `dev_dependencies` and run `dart run build_runner build`. The builder is
/// picked up automatically through `build.yaml`.
///
/// The entry point is exported here for completeness and for tooling that
/// constructs builders programmatically.
library;

export 'builder.dart';
