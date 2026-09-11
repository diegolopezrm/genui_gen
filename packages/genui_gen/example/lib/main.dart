// The smallest complete genui_gen setup: an annotated widget, the generated
// part, and the catalog that registers it.
//
// pubspec.yaml:
//
//   dependencies:
//     genui: ^0.10.0
//     genui_gen: ^0.4.0
//
//   dev_dependencies:
//     build_runner: ^2.15.0
//     genui_gen_builder: ^0.4.0
//
// Then `dart run build_runner build` writes two files next to this one, both
// generated output and both committed here so the example compiles as you see
// it: `main.genui.dart`, declaring `productCardCatalogItem`, and
// `genui_catalog.g.dart`, which lists every generated item in the package as
// `genUiCatalogItems`. With a single widget the item is named directly in
// `buildCatalog()` below; in an app with several, spreading
// `...genUiCatalogItems` is what keeps the catalog from falling behind.
//
// A full app, with six annotated widgets rendered through genui's
// DebugCatalogView, is in the repository's top-level `example/` directory:
// https://github.com/diegolopezrm/genui_gen/tree/main/example

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'main.genui.dart';

@GenUiWidget(description: 'A product card with price and optional image.')
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    this.imageUrl,
    this.favourite = false,
    this.onTap,
    @GenUiWrites('favourite') this.onFavouriteChanged,
  });

  /// Product name.
  final String title;

  /// Price in USD.
  final double price;

  /// Optional image URL.
  final String? imageUrl;

  /// Whether the user has marked the product as a favourite. Bind it to a data
  /// path to read the answer back.
  final bool favourite;

  /// Fired when the card is tapped.
  final VoidCallback? onTap;

  /// Called with the new state when the user taps the heart.
  final ValueChanged<bool>? onFavouriteChanged;

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
            IconButton(
              icon: Icon(favourite ? Icons.favorite : Icons.favorite_border),
              // The generated builder hands this a callback that writes the
              // new state into the data model, at the path `favourite` is
              // bound to.
              onPressed: onFavouriteChanged == null
                  ? null
                  : () => onFavouriteChanged!(!favourite),
            ),
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
