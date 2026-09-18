import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'genui_catalog.g.dart';

void main() {
  runApp(const GenUiGenExampleApp());
}

/// The catalog handed to genui: every generated item in this app, plus genui's
/// basic catalog so the generated examples can reference core components such
/// as `Text`.
///
/// `genUiCatalog` comes from `genui_catalog.g.dart`, which the builder
/// rewrites whenever a `@GenUiWidget` is added or removed, and carries the
/// `catalog_id` set in `build.yaml`. Adding a widget is one file; nothing here
/// has to be touched.
final Catalog exampleCatalog = genUiCatalog.copyWith(
  newItems: BasicCatalogItems.asCatalog().items.toList(),
);

/// Renders every catalog item's generated example offline, with no LLM.
class GenUiGenExampleApp extends StatelessWidget {
  const GenUiGenExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'genui_gen example',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const CatalogGalleryPage(),
    );
  }
}

/// Lists the example of each catalog item and echoes dispatched user actions
/// (for instance `panel_closed` or `onTap`) in a snack bar.
class CatalogGalleryPage extends StatelessWidget {
  const CatalogGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('genui_gen example')),
      body: DebugCatalogView(
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
      ),
    );
  }
}
