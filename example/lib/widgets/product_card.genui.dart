// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'product_card.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [ComponentImplementation] for [ProductCard].
final ComponentImplementation productCardCatalogItem = ComponentImplementation(
  name: 'ProductCard',
  schema: GenUiSchemas.component(
    description:
        'A card that presents a single product with its name, price '
        'in USD and an optional image. Use it to show one item of a '
        'catalog or a search result. Tapping the card fires its onTap '
        'action.',
    properties: {
      'title': GenUiSchemas.string(
        description: 'The product name shown as the card headline.',
      ),
      'price': GenUiSchemas.number(description: 'The product price in USD.'),
      'imageUrl': GenUiSchemas.string(
        description: 'An optional URL of an image shown above the title.',
      ),
      'onTap': GenUiSchemas.action(
        description: 'Fired when the user taps the card.',
      ),
    },
    required: ['title', 'price'],
  ),
  builder: (context, node, props, buildChild) => ProductCard(
    title: props.string('title') ?? '',
    price: props.number('price') ?? 0,
    imageUrl: props.string('imageUrl'),
    onTap: props.action('onTap'),
  ),
);
