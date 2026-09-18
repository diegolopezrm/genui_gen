import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

CatalogItem _item(String name) => CatalogItem(
  name: name,
  dataSchema: S.object(
    description: 'A $name.',
    properties: {'label': S.string(), 'count': S.integer()},
    required: ['label'],
  ),
  widgetBuilder: (ctx) => const SizedBox.shrink(),
);

Catalog _catalog({String? catalogId = 'dev.dlsoft.test'}) =>
    Catalog([_item('Alpha'), _item('Beta')], catalogId: catalogId);

void main() {
  group('genUiCatalogJson', () {
    test('describes every item as an A2UI component', () {
      final json = genUiCatalogJson(_catalog());

      final components = json['components']! as Map<String, Object?>;
      expect(components.keys, containsAll(<String>['Alpha', 'Beta']));

      final alpha = components['Alpha']! as Map<String, Object?>;
      // `unevaluatedProperties: false` is what stops a model from inventing a
      // property the widget does not take.
      expect(alpha['unevaluatedProperties'], isFalse);

      final own = (alpha['allOf']! as List).last as Map<String, Object?>;
      final properties = own['properties']! as Map<String, Object?>;
      // Pinned to this component's name, which is how a renderer knows which
      // entry of `anyComponent` it is looking at. genui writes it as a `const`
      // and `CatalogItem.dataSchema` then overwrites it with a one-value
      // `enum`; both say the same thing, so neither is asserted over the
      // other.
      expect(
        properties['component'],
        anyOf(
          equals(<String, Object?>{'const': 'Alpha'}),
          equals(<String, Object?>{
            'type': 'string',
            'enum': <String>['Alpha'],
          }),
        ),
      );
      expect(properties.keys, containsAll(<String>['label', 'count']));
      // The discriminator the renderer switches on is required alongside the
      // widget's own required properties.
      expect(own['required'], containsAll(<String>['component', 'label']));
    });

    test('carries the catalog id a surface names', () {
      expect(genUiCatalogJson(_catalog())['catalogId'], 'dev.dlsoft.test');
    });

    test('lets a component be resolved by name', () {
      final defs = genUiCatalogJson(_catalog())[r'$defs']! as Map<String, Object?>;
      final anyComponent = defs['anyComponent']! as Map<String, Object?>;
      expect(anyComponent['discriminator'], {'propertyName': 'component'});
      expect(anyComponent['oneOf'], [
        {r'$ref': '#/components/Alpha'},
        {r'$ref': '#/components/Beta'},
      ]);
    });

    test('takes a title and description of its own', () {
      final json = genUiCatalogJson(
        _catalog(),
        title: 'Acme Catalog',
        description: 'The components the Acme app renders.',
      );

      expect(json['title'], 'Acme Catalog');
      expect(json['description'], 'The components the Acme app renders.');
    });

    test('keeps the generic title when none is given', () {
      expect(genUiCatalogJson(_catalog())['title'], 'A2UI Catalog');
    });

    test('rejects a catalog with no id', () {
      expect(
        () => genUiCatalogJson(_catalog(catalogId: null)),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('catalogId'),
          ),
        ),
      );
    });

    test('does not hand out the schema itself to edit', () {
      final catalog = _catalog();
      genUiCatalogJson(catalog, title: 'Edited')['components'] = 'gone';

      expect(catalog.fullSchema.value['title'], 'A2UI Catalog');
      expect(catalog.fullSchema.value['components'], isA<Map<String, Object?>>());
    });
  });

  group('genUiCatalogJsonString', () {
    test('encodes what genUiCatalogJson returns', () {
      final catalog = _catalog();

      expect(
        jsonDecode(genUiCatalogJsonString(catalog)),
        genUiCatalogJson(catalog),
      );
    });

    test('indents, so the file can be reviewed', () {
      expect(genUiCatalogJsonString(_catalog()), contains('\n  "components"'));
    });
  });
}
