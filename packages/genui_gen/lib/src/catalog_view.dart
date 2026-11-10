import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';

import 'component.dart';
import 'example_surface.dart';

/// Every example of every generated component in [catalog], each rendered on
/// a surface of its own.
///
/// What genui's `DebugCatalogView` was for: a screen to look at the catalog as
/// the agent is shown it, with the same names and the same examples, rendered
/// by the same renderer. Components that carry no examples, such as the basic
/// ones, are left out.
class GenUiCatalogView extends StatelessWidget {
  /// Creates a [GenUiCatalogView].
  const GenUiCatalogView({super.key, required this.catalog, this.onAction});

  /// The catalog to show, which also holds the components the examples
  /// compose with.
  final CatalogImplementation catalog;

  /// Called with each action an example sends.
  final ValueChanged<A2uiRendererAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<GenUiComponent> components = [
      for (final ComponentImplementation component in catalog.components.values)
        if (component is GenUiComponent && component.examples.isNotEmpty)
          component,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final GenUiComponent component in components)
          for (var i = 0; i < component.examples.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    component.examples.length == 1
                        ? component.name
                        : '${component.name} ${i + 1}',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  GenUiExampleSurface(
                    catalog: catalog,
                    component: component,
                    exampleIndex: i,
                    onAction: onAction,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
