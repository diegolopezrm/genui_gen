import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

CatalogItem _item(String name) => CatalogItem(
  name: name,
  schema: S.object(
    description: 'A $name.',
    properties: {'label': S.string(), 'count': S.integer()},
    required: ['label'],
  ),
  builder: (context, node, props, buildChild) => const SizedBox.shrink(),
);

CatalogImplementation _catalog() => CatalogImplementation(
  id: 'dev.dlsoft.test',
  components: [_item('Alpha'), _item('Beta')],
);

void main() {
  group('genUiCatalogJson', () {
    test('describes every item as an A2UI component', () {
      final json = genUiCatalogJson(_catalog());

      final components = json['components']! as Map<String, Object?>;
      expect(components.keys, containsAll(<String>['Alpha', 'Beta']));

      // A catalog defined in code is written with each component's schema as
      // it was declared.
      final alpha = components['Alpha']! as Map<String, Object?>;
      expect(alpha['description'], 'A Alpha.');
      final properties = alpha['properties']! as Map<String, Object?>;
      expect(properties.keys, containsAll(<String>['label', 'count']));
      expect(alpha['required'], <String>['label']);
    });

    test('carries the catalog id a surface names', () {
      expect(genUiCatalogJson(_catalog())['catalogId'], 'dev.dlsoft.test');
    });

    test('lets a component be resolved by name', () {
      final defs =
          genUiCatalogJson(_catalog())[r'$defs']! as Map<String, Object?>;
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

    test('has no title of its own unless given one', () {
      expect(genUiCatalogJson(_catalog()).containsKey('title'), isFalse);
    });

    test('does not hand out the document itself to edit', () {
      final catalog = _catalog();
      genUiCatalogJson(catalog, title: 'Edited')['components'] = 'gone';

      final Map<String, Object?> again = genUiCatalogJson(catalog);
      expect(again.containsKey('title'), isFalse);
      expect(again['components'], isA<Map<String, Object?>>());
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
