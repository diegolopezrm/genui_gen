// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'product_card.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [ProductCard].
final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  schema: S.object(
    description:
        'A card that presents a single product with its name, price '
        'in USD and an optional image. Use it to show one item of a '
        'catalog or a search result. Tapping the card fires its onTap '
        'action.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'The product name shown as the card headline.',
      }),
      'price': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description': 'The product price in USD.',
      }),
      'imageUrl': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'An optional URL of an image shown above the title.',
      }),
      'onTap': S.fromMap({
        ...CommonSchemas.action.value,
        'description': 'Fired when the user taps the card.',
      }),
    },
    required: ['title', 'price'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Quarterly report",
    "price": 19.99,
    "imageUrl": "https://picsum.photos/seed/genui_gen/400/225",
    "onTap": {
      "event": {
        "name": "onTap"
      }
    }
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'ProductCard', property);
      return fallback;
    }

    return ProductCard(
      title:
          genUiAsString(props.value('title')) ?? missing<String>('title', ''),
      price: (genUiAsNum(props.value('price')) ?? missing<num>('price', 0))
          .toDouble(),
      imageUrl: genUiAsString(props.value('imageUrl')),
      onTap: genUiActionHandler(props.action('onTap')),
    );
  },
);
