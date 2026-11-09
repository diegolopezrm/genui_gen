/// Regression guard for the 0.1 output shape.
///
/// A widget that uses only the types 0.1 supported must keep generating
/// exactly the same file as features are added. The golden below was the
/// byte-for-byte output of the 0.1.2 builder until the move from genui to
/// a2ui_flutter, which changed every line of it; it is now the output of the
/// first builder on a2ui_flutter.
library;

import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  test('a 0.1-only widget generates byte-identical output', () async {
    expect(await generateRaw(_widget), _golden);
  });
}

const _widget = '''
/// The direction a metric is moving in.
enum Trend { up, down, flat }

/// A card summarising one product.
@GenUiWidget(description: 'A product card with price and image.')
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.title,
    required this.price,
    required this.quantity,
    required this.rating,
    required this.inStock,
    required this.trend,
    required this.tags,
    required this.leading,
    required this.children,
    this.imageUrl,
    this.subtitle = 'None',
    @GenUiAction(eventName: 'tapped') this.onTap,
  });

  /// Product name.
  final String title;
  /// Price in USD.
  final double price;
  final int quantity;
  final num rating;
  final bool inStock;
  final Trend trend;
  final List<String> tags;
  final Widget leading;
  final List<Widget> children;
  final String? imageUrl;
  final String subtitle;
  final VoidCallback? onTap;
}
''';

const _golden = r"""
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'widget.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [ProductCard].
final CatalogItem productCardCatalogItem = CatalogItem(
  name: 'ProductCard',
  schema: S.object(
    description: 'A product card with price and image.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'Product name.',
      }),
      'price': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description': 'Price in USD.',
      }),
      'quantity': CommonSchemas.dynamicNumber,
      'rating': CommonSchemas.dynamicNumber,
      'inStock': CommonSchemas.dynamicBoolean,
      'trend': S.combined(
        anyOf: [
          S.string(enumValues: ['up', 'down', 'flat']),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
      'tags': CommonSchemas.dynamicStringList,
      'leading': CommonSchemas.componentId,
      'children': S.list(items: CommonSchemas.componentId),
      'imageUrl': CommonSchemas.dynamicString,
      'subtitle': CommonSchemas.dynamicString,
      'onTap': CommonSchemas.action,
    },
    required: [
      'title',
      'price',
      'quantity',
      'rating',
      'inStock',
      'trend',
      'tags',
      'leading',
      'children',
    ],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "ProductCard",
    "title": "Quarterly report",
    "price": 19.99,
    "quantity": 3,
    "rating": 5,
    "inStock": true,
    "trend": "up",
    "tags": [
      "Alpha",
      "Beta"
    ],
    "leading": "child_leading",
    "children": [
      "child_children_1",
      "child_children_2"
    ],
    "imageUrl": "https://picsum.photos/seed/genui_gen/400/225",
    "onTap": {
      "event": {
        "name": "tapped"
      }
    }
  },
  {
    "id": "child_leading",
    "component": "Text",
    "text": "Sample leading"
  },
  {
    "id": "child_children_1",
    "component": "Text",
    "text": "Sample children 1"
  },
  {
    "id": "child_children_2",
    "component": "Text",
    "text": "Sample children 2"
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
      quantity:
          (genUiAsNum(props.value('quantity')) ?? missing<num>('quantity', 0))
              .toInt(),
      rating: genUiAsNum(props.value('rating')) ?? missing<num>('rating', 0),
      inStock:
          genUiAsBool(props.value('inStock')) ??
          missing<bool>('inStock', false),
      trend:
          Trend.values.asNameMap()[genUiAsString(props.value('trend'))] ??
          missing<Trend>('trend', Trend.values.first),
      tags:
          genUiAsStringList(props.value('tags')) ??
          missing<List<String>>('tags', const <String>[]),
      leading: switch (props.child('leading')) {
        final child? => buildChild(child),
        _ => missing<Widget>('leading', const SizedBox.shrink()),
      },
      children: props.value('children') is List
          ? [for (final child in props.children('children')) buildChild(child)]
          : missing<List<Widget>>('children', const <Widget>[]),
      imageUrl: genUiAsString(props.value('imageUrl')),
      subtitle: genUiAsString(props.value('subtitle')) ?? 'None',
      onTap: genUiActionHandler(props.action('onTap')),
    );
  },
);
""";
