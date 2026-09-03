import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'product_card.genui.dart';

/// A Material card presenting a single product.
///
/// Shows an optional image on top, the product [title] and its [price].
/// The whole card is tappable when [onTap] is provided.
@GenUiWidget(
  description:
      'A card that presents a single product with its name, price in USD and '
      'an optional image. Use it to show one item of a catalog or a search '
      'result. Tapping the card fires its onTap action.',
)
class ProductCard extends StatelessWidget {
  /// Creates a product card.
  const ProductCard({
    super.key,

    /// The product name shown as the card headline.
    required this.title,

    /// The product price in USD.
    required this.price,

    /// An optional URL of an image shown above the title.
    this.imageUrl,

    /// Fired when the user taps the card.
    this.onTap,
  });

  /// The product name shown as the card headline.
  final String title;

  /// The product price in USD.
  final double price;

  /// An optional URL of an image shown above the title.
  final String? imageUrl;

  /// Fired when the user taps the card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? imageUrl = this.imageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
