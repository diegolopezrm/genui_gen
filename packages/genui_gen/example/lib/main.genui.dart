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
  schema: S.object(
    description: 'A product card with price and optional image.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'Product name.',
      }),
      'price': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description': 'Price in USD.',
      }),
      'imageUrl': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'Optional image URL.',
      }),
      'favourite': S.fromMap({
        ...CommonSchemas.dynamicBoolean.value,
        'description':
            'Whether the user has marked the product as a favourite. Bind '
            'it to a data path to read the answer back. The component '
            'writes the value the user chooses back to this property, so '
            'bind it to a data path if you need to read the result.',
      }),
      'onTap': S.fromMap({
        ...CommonSchemas.action.value,
        'description': 'Fired when the card is tapped.',
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
      favourite:
          genUiAsBool(genUiWrittenValue(node, props, 'favourite')) ?? false,
      onTap: genUiActionHandler(props.action('onTap')),
      onFavouriteChanged: genUiValueWriter<bool>(node, props, 'favourite'),
    );
  },
);
