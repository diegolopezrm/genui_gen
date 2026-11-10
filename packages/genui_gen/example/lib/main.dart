// The smallest complete genui_gen setup: an annotated widget, the generated
// part, and the catalog that registers it.
//
// pubspec.yaml:
//
//   dependencies:
//     a2ui_flutter: ^0.2.0
//     genui_gen: ^0.15.0
//
//   dev_dependencies:
//     build_runner: ^2.15.0
//     genui_gen_builder: ^0.14.0
//
// Then `dart run build_runner build` writes two files next to this one, both
// generated output and both committed here so the example compiles as you see
// it: `main.genui.dart`, declaring `productCardCatalogItem`, and
// `genui_catalog.g.dart`, which lists every generated component in the
// package as `genUiCatalogItems`. With a single widget the component is named
// directly in `buildCatalog()` below; in an app with several, spreading
// `...genUiCatalogItems` is what keeps the catalog from falling behind.
//
// A full app, with the generated components rendered by a2ui_flutter, is in
// the repository's top-level `example/` directory:
// https://github.com/diegolopezrm/genui_gen/tree/main/example

import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:flutter/material.dart';
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
              // bound to, or null when the agent sent a literal.
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

/// Registers the generated component next to the basic catalog.
///
/// A v0.9 surface draws on one catalog, so the basic components an agent
/// composes the card with, a `Row` or a `Text`, belong in the same one.
CatalogImplementation buildCatalog() => basicCatalog().derive(
  catalogId: 'com.example.shop',
  addComponents: [productCardCatalogItem],
);
