import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

/// A one-component catalog, as `genUiCatalogJson` writes it.
Map<String, Object?> catalogWith({
  Map<String, Schema> properties = const {},
  List<String> required = const ['title'],
  String catalogId = 'dev.dlsoft.test',
  String description = 'A product card.',
}) => genUiCatalogJson(
  Catalog([
    CatalogItem(
      name: 'ProductCard',
      dataSchema: S.object(
        description: description,
        properties: {'title': S.string(), ...properties},
        required: required,
      ),
      widgetBuilder: (ctx) => const SizedBox.shrink(),
    ),
  ], catalogId: catalogId),
);

void main() {
  test('an unchanged catalog has nothing to report', () {
    expect(genUiCatalogDiff(catalogWith(), catalogWith()), isEmpty);
  });

  test('a new optional property is not breaking', () {
    final changes = genUiCatalogDiff(
      catalogWith(),
      catalogWith(properties: {'subtitle': S.string()}),
    );

    expect(changes, hasLength(1));
    expect(changes.single.kind, GenUiCatalogChangeKind.propertyAdded);
    expect(changes.single.where, 'ProductCard.subtitle');
    expect(changes.single.isBreaking, isFalse);
  });

  test('a new required property is breaking', () {
    final changes = genUiCatalogDiff(
      catalogWith(),
      catalogWith(
        properties: {'price': S.number()},
        required: ['title', 'price'],
      ),
    );

    expect(changes.single.kind, GenUiCatalogChangeKind.propertyBecameRequired);
    expect(changes.single.isBreaking, isTrue);
  });

  test('a property that disappears is breaking', () {
    final changes = genUiCatalogDiff(
      catalogWith(properties: {'subtitle': S.string()}),
      catalogWith(),
    );

    expect(changes.single.kind, GenUiCatalogChangeKind.propertyRemoved);
    expect(changes.single.isBreaking, isTrue);
  });

  test('a property that changes type is breaking, and says how', () {
    final changes = genUiCatalogDiff(
      catalogWith(properties: {'price': S.string()}),
      catalogWith(properties: {'price': S.number()}),
    );

    final change = changes.firstWhere(
      (change) => change.kind == GenUiCatalogChangeKind.propertyTypeChanged,
    );
    expect(change.detail, contains('->'));
    expect(change.isBreaking, isTrue);
  });

  test('an enum that loses a value is breaking, and names it', () {
    final changes = genUiCatalogDiff(
      catalogWith(
        properties: {
          'variant': S.string(enumValues: ['solid', 'outline', 'ghost']),
        },
      ),
      catalogWith(
        properties: {
          'variant': S.string(enumValues: ['solid', 'outline']),
        },
      ),
    );

    final change = changes.firstWhere(
      (change) => change.kind == GenUiCatalogChangeKind.enumValueRemoved,
    );
    expect(change.detail, 'ghost');
    expect(change.isBreaking, isTrue);
  });

  test('an enum that gains a value is not breaking', () {
    final changes = genUiCatalogDiff(
      catalogWith(
        properties: {
          'variant': S.string(enumValues: ['solid']),
        },
      ),
      catalogWith(
        properties: {
          'variant': S.string(enumValues: ['solid', 'ghost']),
        },
      ),
    );

    expect(changes.single.kind, GenUiCatalogChangeKind.enumValueAdded);
    expect(changes.single.isBreaking, isFalse);
  });

  test('a component that disappears is breaking', () {
    final before = genUiCatalogJson(
      Catalog([
        CatalogItem(
          name: 'Gone',
          dataSchema: S.object(description: 'A component.', properties: {}),
          widgetBuilder: (ctx) => const SizedBox.shrink(),
        ),
      ], catalogId: 'dev.dlsoft.test'),
    );

    final changes = genUiCatalogDiff(before, catalogWith());

    expect(
      changes.map((change) => change.kind),
      containsAll([
        GenUiCatalogChangeKind.componentRemoved,
        GenUiCatalogChangeKind.componentAdded,
      ]),
    );
    expect(changes.first.isBreaking, isTrue, reason: changes.join('\n'));
  });

  test('a reworded property description is reported, but is not breaking', () {
    final changes = genUiCatalogDiff(
      catalogWith(properties: {'price': S.number(description: 'In USD.')}),
      catalogWith(
        properties: {'price': S.number(description: 'In the shop currency.')},
      ),
    );

    expect(changes.single.kind, GenUiCatalogChangeKind.descriptionChanged);
    expect(changes.single.where, 'ProductCard.price');
    expect(changes.single.isBreaking, isFalse);
  });

  test('a renamed catalog is breaking: a surface names it', () {
    final changes = genUiCatalogDiff(
      catalogWith(),
      catalogWith(catalogId: 'dev.dlsoft.renamed'),
    );

    expect(changes.single.kind, GenUiCatalogChangeKind.catalogIdChanged);
    expect(changes.single.detail, contains('dev.dlsoft.renamed'));
  });

  test('breaking changes are listed first', () {
    final changes = genUiCatalogDiff(
      catalogWith(),
      catalogWith(
        properties: {'price': S.number(), 'subtitle': S.string()},
        required: ['title', 'price'],
      ),
    );

    expect(changes.length, greaterThan(1));
    expect(changes.first.isBreaking, isTrue);
    expect(changes.last.isBreaking, isFalse);
  });
}
