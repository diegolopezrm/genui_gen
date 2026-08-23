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
  dataSchema: S.object(
    description:
        'A card that presents a single product with its name, price '
        'in USD and an optional image. Use it to show one item of a '
        'catalog or a search result. Tapping the card fires its onTap '
        'action.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'The product name shown as the card headline.',
      ),
      'price': A2uiSchemas.numberReference(
        description: 'The product price in USD.',
      ),
      'imageUrl': A2uiSchemas.stringReference(
        description: 'An optional URL of an image shown above the title.',
      ),
      'onTap': A2uiSchemas.action(
        description: 'Fired when the user taps the card.',
      ),
    },
    required: ['title', 'price'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Sample title",
    "price": 42.5,
    "imageUrl": "https://example.com/sample.png",
    "onTap": {
      "event": {
        "name": "onTap"
      }
    }
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'ProductCard', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'price': GenUiBinding.number(data['price']),
        'imageUrl': GenUiBinding.string(data['imageUrl']),
      },
      builder: (context, v) => ProductCard(
        title: v.string('title') ?? missing<String>('title', ''),
        price: (v.number('price') ?? missing<num>('price', 0)).toDouble(),
        imageUrl: v.string('imageUrl'),
        onTap: genUiActionHandler(ctx, data['onTap']),
      ),
    );
  },
);
