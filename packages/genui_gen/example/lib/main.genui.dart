// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'main.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [ProductCard].
final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  dataSchema: S.object(
    description: 'A product card with price and optional image.',
    properties: {
      'title': A2uiSchemas.stringReference(description: 'Product name.'),
      'price': A2uiSchemas.numberReference(description: 'Price in USD.'),
      'imageUrl': A2uiSchemas.stringReference(
        description: 'Optional image URL.',
      ),
      'onTap': A2uiSchemas.action(
        description: 'Fired when the card is tapped.',
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
    "imageUrl": "https://picsum.photos/seed/genui_gen/400/225",
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
