import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

ComponentImplementation _component(String name) => ComponentImplementation(
  name: name,
  schema: GenUiSchemas.component(
    description: 'A $name.',
    properties: {
      'label': GenUiSchemas.string(description: 'What it says.'),
      'count': GenUiSchemas.number(),
    },
    required: ['label'],
  ),
  builder: (context, node, props, buildChild) => const SizedBox.shrink(),
);

CatalogImplementation _catalog() => CatalogImplementation(
  id: 'dev.dlsoft.test',
  components: [_component('Alpha'), _component('Beta')],
);

void main() {
  group('genUiCatalogJson', () {
    test('describes every component', () {
      final json = genUiCatalogJson(_catalog());

      final components = json['components']! as Map<String, Object?>;
      expect(components.keys, containsAll(<String>['Alpha', 'Beta']));

      final alpha = components['Alpha']! as Map<String, Object?>;
      // What stops a model from inventing a property the widget does not take.
      expect(alpha['unevaluatedProperties'], isFalse);
      final properties = alpha['properties']! as Map<String, Object?>;
      expect(properties['component'], {'const': 'Alpha'});
      // A shared type is a reference, with this property's own description.
      expect(properties['label'], {
        r'$ref': r'#/$defs/DynamicString',
        'description': 'What it says.',
      });
      expect(alpha['required'], containsAll(<String>['component', 'label']));
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

    test('does not hand out the catalog document itself to edit', () {
      final catalog = _catalog();
      genUiCatalogJson(catalog, title: 'Edited')['components'] = 'gone';

      expect(catalog.validationSchema['title'], isNull);
      expect(
        catalog.validationSchema['components'],
        isA<Map<String, Object?>>(),
      );
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
