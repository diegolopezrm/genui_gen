/// Regression guard for the 0.1 output shape.
///
/// A widget that uses only the types 0.1 supported must keep generating
/// exactly the same file after `@GenUiData` support was added in 0.2. The
/// golden below is the byte-for-byte output of the 0.1.2 builder.
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
  dataSchema: S.object(
    description: 'A product card with price and image.',
    properties: {
      'title': A2uiSchemas.stringReference(description: 'Product name.'),
      'price': A2uiSchemas.numberReference(description: 'Price in USD.'),
      'quantity': A2uiSchemas.numberReference(),
      'rating': A2uiSchemas.numberReference(),
      'inStock': A2uiSchemas.booleanReference(),
      'trend': A2uiSchemas.stringReference(enumValues: ['up', 'down', 'flat']),
      'tags': A2uiSchemas.stringArrayReference(),
      'leading': A2uiSchemas.componentReference(),
      'children': S.list(items: A2uiSchemas.componentReference()),
      'imageUrl': A2uiSchemas.stringReference(),
      'subtitle': A2uiSchemas.stringReference(),
      'onTap': A2uiSchemas.action(),
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
    "title": "Sample title",
    "price": 42.5,
    "quantity": 42,
    "rating": 42,
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'ProductCard', property);
      return fallback;
    }

    final _leading = data['leading'];
    final _children = data['children'];
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'price': GenUiBinding.number(data['price']),
        'quantity': GenUiBinding.number(data['quantity']),
        'rating': GenUiBinding.number(data['rating']),
        'inStock': GenUiBinding.bool(data['inStock']),
        'trend': GenUiBinding.string(data['trend']),
        'tags': GenUiBinding.stringList(data['tags']),
        'imageUrl': GenUiBinding.string(data['imageUrl']),
        'subtitle': GenUiBinding.string(data['subtitle']),
      },
      builder: (context, v) => ProductCard(
        title: v.string('title') ?? missing<String>('title', ''),
        price: (v.number('price') ?? missing<num>('price', 0)).toDouble(),
        quantity: (v.number('quantity') ?? missing<num>('quantity', 0)).toInt(),
        rating: v.number('rating') ?? missing<num>('rating', 0),
        inStock: v.boolean('inStock') ?? missing<bool>('inStock', false),
        trend:
            Trend.values.asNameMap()[v.string('trend')] ??
            missing<Trend>('trend', Trend.values.first),
        tags:
            v.stringList('tags') ??
            missing<List<String>>('tags', const <String>[]),
        leading: _leading is String
            ? ctx.buildChild(_leading)
            : missing<Widget>('leading', const SizedBox.shrink()),
        children: _children is List
            ? _children
                  .whereType<String>()
                  .map((id) => ctx.buildChild(id))
                  .toList()
            : missing<List<Widget>>('children', const <Widget>[]),
        imageUrl: v.string('imageUrl'),
        subtitle: v.string('subtitle') ?? 'None',
        onTap: genUiActionHandler(ctx, data['onTap']),
      ),
    );
  },
);
""";
