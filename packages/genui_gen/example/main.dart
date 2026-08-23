// A minimal annotated widget. Run `dart run build_runner build` with
// `genui_gen_builder` in dev_dependencies and add
// `part 'main.genui.dart';` below the imports to get `productCardCatalogItem`.
//
// The complete, runnable app lives in the repository's `example/` directory:
// https://github.com/dieg0lopez/genui_gen/tree/main/example

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

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
/// `productCardCatalogItem` is declared by the generated part.
Catalog buildCatalog(CatalogItem productCardCatalogItem) {
  return BasicCatalogItems.asCatalog().copyWith(
    newItems: [productCardCatalogItem],
  );
}
