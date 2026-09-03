// The smallest complete genui_gen setup: an annotated widget, the generated
// part, and the catalog that registers it.
//
// pubspec.yaml:
//
//   dependencies:
//     genui: ^0.10.0
//     genui_gen: ^0.2.0
//     json_schema_builder: ^0.1.3
//
//   dev_dependencies:
//     build_runner: ^2.15.0
//     genui_gen_builder: ^0.2.0
//
// Then `dart run build_runner build` writes `main.genui.dart` next to this
// file, declaring `productCardCatalogItem`. That file is generated output and
// is committed here so this example compiles as you see it.
//
// A full app, with five annotated widgets rendered through genui's
// DebugCatalogView, is in the repository's top-level `example/` directory:
// https://github.com/diegolopezrm/genui_gen/tree/main/example

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

part 'main.genui.dart';

@GenUiWidget(description: 'A product card with price and optional image.')
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    this.imageUrl,
    this.onTap,
  });

  /// Product name.
  final String title;

  /// Price in USD.
  final double price;

  /// Optional image URL.
  final String? imageUrl;

  /// Fired when the card is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) Image.network(imageUrl!),
            Text(title),
            Text('\$$price'),
          ],
        ),
      ),
    );
  }
}

/// Registers the generated item next to genui's basic catalog.
///
/// The basic items have to be there: a generated example composes genui's own
/// `Text` for its child components, so a catalog without them fails validation.
Catalog buildCatalog() {
  return BasicCatalogItems.asCatalog().copyWith(
    newItems: [productCardCatalogItem],
  );
}
