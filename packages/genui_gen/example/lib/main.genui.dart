// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'main.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [GenUiComponent] for [ProductCard].
final GenUiComponent productCardCatalogItem = GenUiComponent(
  name: 'ProductCard',
  schema: GenUiSchemas.component(
    description: 'A product card with price and optional image.',
    properties: {
      'title': GenUiSchemas.string(description: 'Product name.'),
      'price': GenUiSchemas.number(description: 'Price in USD.'),
      'imageUrl': GenUiSchemas.string(description: 'Optional image URL.'),
      'favourite': GenUiSchemas.boolean(
        description:
            'Whether the user has marked the product as a favourite. Bind '
            'it to a data path to read the answer back. The component '
            'writes the value the user chooses back to this property, so '
            'bind it to a data path if you need to read the result.',
      ),
      'onTap': GenUiSchemas.action(
        description: 'Fired when the card is tapped.',
      ),
    },
    required: ['title', 'price'],
  ),
  examples: [
    r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Quarterly report",
    "price": 19.99,
    "imageUrl": "https://picsum.photos/seed/genui_gen/400/225",
    "favourite": {
      "path": "/favourite"
    },
    "onTap": {
      "event": {
        "name": "onTap"
      }
    }
  }
]''',
  ],
  builder: (context, node, props, buildChild) => ProductCard(
    title: props.string('title') ?? '',
    price: props.number('price') ?? 0,
    imageUrl: props.string('imageUrl'),
    favourite: props.boolean('favourite') ?? false,
    onTap: props.action('onTap'),
    onFavouriteChanged: genUiWriter<bool>(context, props, 'favourite'),
  ),
);
