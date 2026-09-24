import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import '../main.dart';

/// Every component the model may ask for, rendered from the example the
/// generator derived from each widget's constructor.
///
/// This is the catalog as the agent sees it: the same names, the same
/// properties, the same examples that go into the prompt.
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DebugCatalogView(
      catalog: exampleCatalog,
      onSubmit: (ChatMessage message) {
        final String interactions = message.parts.uiInteractionParts
            .map((part) => part.interaction)
            .join('\n');
        if (interactions.isEmpty) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(interactions)));
      },
    );
  }
}
