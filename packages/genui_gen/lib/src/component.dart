import 'dart:convert';

import 'package:a2ui_flutter/a2ui_flutter.dart';

/// A [ComponentImplementation] generated from an annotated widget, with the
/// examples the generator wrote for it.
///
/// An example is a surface that shows the component on its own: the JSON list
/// of components an `updateComponents` message carries, with `root` first and
/// any child it needs after it. The testing tools render every example, and
/// [genUiExampleInstructions] writes them into a catalog's instructions, which
/// is where an agent reads them.
class GenUiComponent extends ComponentImplementation {
  /// Creates a component with [examples].
  const GenUiComponent({
    required super.name,
    required super.schema,
    required super.builder,
    this.examples = const [],
  });

  /// The examples, each a JSON list of components with `root` first.
  final List<String> examples;
}

/// The instructions that show an agent an example of each component in
/// [components] that has one, or `null` when none has.
///
/// A catalog's instructions travel in its document, so an agent written in
/// any language reads them next to the schemas, which is where an example
/// helps most: it shows the shape the schema only describes. Each example is
/// written as compact JSON, so it costs the prompt as little as it can.
String? genUiExampleInstructions(Iterable<ComponentImplementation> components) {
  final out = StringBuffer();
  for (final component in components) {
    if (component is! GenUiComponent) continue;
    for (final String example in component.examples) {
      if (out.isEmpty) {
        out.write(
          'An example of each of these components, as the `components` of an '
          '`updateComponents` message, with `root` first.\n',
        );
      }
      out
        ..write('\n### ${component.name}\n\n```json\n')
        ..write(jsonEncode(jsonDecode(example)))
        ..write('\n```\n');
    }
  }
  return out.isEmpty ? null : out.toString();
}
