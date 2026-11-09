import 'package:a2ui_flutter/a2ui_flutter.dart';

/// A component together with the examples the generator derived for it.
///
/// It is an a2ui_flutter [ComponentImplementation], so it goes into a
/// [CatalogImplementation] like any other component. What it adds is
/// [exampleData]: a2ui_flutter components carry no examples, and the testing
/// helpers in `package:genui_gen/testing.dart` render, fuzz and record a
/// component from its examples.
///
/// The generated part declares one of these per `@GenUiWidget`. Writing one
/// by hand is fine too, and gives the testing helpers something to render.
class CatalogItem extends ComponentImplementation {
  /// Creates a [CatalogItem].
  const CatalogItem({
    required super.name,
    required super.schema,
    required super.builder,
    this.exampleData = const [],
  });

  /// Sample components, each a JSON list of the components of one surface,
  /// rooted at the component with id `root`.
  ///
  /// Functions rather than strings so that an example is only built when
  /// something asks for it.
  final List<String Function()> exampleData;
}
