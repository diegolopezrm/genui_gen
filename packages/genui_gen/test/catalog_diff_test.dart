import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

/// A one-component catalog, as `genUiCatalogJson` writes it.
Map<String, Object?> catalogWith({
  Map<String, Schema> properties = const {},
  List<String> required = const ['title'],
  String catalogId = 'dev.dlsoft.test',
  String description = 'A product card.',
}) => genUiCatalogJson(
  CatalogImplementation(
    id: catalogId,
    components: [
      ComponentImplementation(
        name: 'ProductCard',
        schema: S.object(
          description: description,
          properties: {'title': S.string(), ...properties},
          required: required,
        ),
        builder: (context, node, props, buildChild) => const SizedBox.shrink(),
      ),
    ],
  ),
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
      CatalogImplementation(
        id: 'dev.dlsoft.test',
        components: [
          ComponentImplementation(
            name: 'Gone',
            schema: S.object(description: 'A component.', properties: {}),
            builder: (context, node, props, buildChild) =>
                const SizedBox.shrink(),
          ),
        ],
      ),
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

  test('a child named by its ComponentId reference is still a string', () {
    // a2ui_flutter describes a child as a `$ref` to the protocol's
    // `ComponentId`, where genui spelled out `"type": "string"`. That
    // definition is a string and nothing else, so a message an agent wrote
    // against one is valid against the other.
    final changes = genUiCatalogDiff(
      catalogWith(properties: {'child': S.string()}),
      catalogWith(
        properties: {
          'child': S.combined(
            $ref:
                'https://a2ui.org/specification/v0_9/common_types.json'
                r'#/$defs/ComponentId',
          ),
        },
      ),
    );

    expect(
      changes.where(
        (change) => change.kind == GenUiCatalogChangeKind.propertyTypeChanged,
      ),
      isEmpty,
    );
  });

  test('genui and a2ui_core name a shared definition the same', () {
    // genui points into `common_types.json`; a2ui_core's catalog document
    // carries the definitions in its own `$defs` and points there.
    final changes = genUiCatalogDiff(
      catalogWith(
        properties: {
          'price': S.combined(
            $ref:
                'https://a2ui.org/specification/v0_9/common_types.json'
                r'#/$defs/DynamicNumber',
          ),
        },
      ),
      catalogWith(
        properties: {'price': S.combined($ref: r'#/$defs/DynamicNumber')},
      ),
    );

    expect(changes, isEmpty);
  });

  test('a catalog moved from genui to a2ui_core reads the same', () {
    // The same three properties as each renderer writes them: genui inlines a
    // data binding and a function call, narrows the shared definition to an
    // enum and spells a child list out; a2ui_core points at the shared
    // definitions, spells the enum's union out, and lists `id`.
    const String common =
        'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/';
    final genui = <String, Object?>{
      'components': {
        'Tile': {
          'allOf': [
            {r'$ref': '${common}ComponentCommon'},
            {
              'properties': {
                'component': {'const': 'Tile'},
                'trend': {
                  'allOf': [
                    {r'$ref': '${common}DynamicString'},
                    {
                      'anyOf': [
                        {
                          'type': 'string',
                          'enum': ['up', 'down'],
                        },
                        {'type': 'object'},
                      ],
                    },
                  ],
                },
                'history': {
                  'oneOf': [
                    {
                      'type': 'array',
                      'items': {'type': 'number'},
                    },
                    {
                      'type': 'object',
                      'properties': {
                        'path': {'type': 'string'},
                      },
                    },
                    {
                      'type': 'object',
                      'properties': {
                        'call': {'type': 'string'},
                      },
                    },
                  ],
                },
                'rows': {
                  'oneOf': [
                    {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    {
                      'type': 'object',
                      'properties': {
                        'componentId': {'type': 'string'},
                        'path': {'type': 'string'},
                      },
                    },
                  ],
                },
              },
              'required': ['component', 'trend'],
            },
          ],
        },
      },
    };
    final a2ui = <String, Object?>{
      'components': {
        'Tile': {
          'type': 'object',
          'properties': {
            'id': {r'$ref': r'#/$defs/ComponentId'},
            'component': {'const': 'Tile'},
            'trend': {
              'anyOf': [
                {
                  'type': 'string',
                  'enum': ['up', 'down'],
                },
                {r'$ref': r'#/$defs/DataBinding'},
                {r'$ref': r'#/$defs/FunctionCall'},
              ],
            },
            'history': {
              'anyOf': [
                {
                  'type': 'array',
                  'items': {'type': 'number'},
                },
                {r'$ref': r'#/$defs/DataBinding'},
                {r'$ref': r'#/$defs/FunctionCall'},
              ],
            },
            'rows': {r'$ref': r'#/$defs/ChildList'},
          },
          'required': ['id', 'trend', 'component'],
        },
      },
    };

    expect(genUiCatalogDiff(genui, a2ui), isEmpty);
  });

  test('an enum value removed inside the union is still found', () {
    Map<String, Object?> withTrend(List<String> values) => catalogWith(
      properties: {'trend': GenUiSchemas.string(enumValues: values)},
    );

    final changes = genUiCatalogDiff(
      withTrend(['up', 'down', 'flat']),
      withTrend(['up', 'down']),
    );

    final GenUiCatalogChange change = changes.singleWhere(
      (change) => change.kind == GenUiCatalogChangeKind.enumValueRemoved,
    );
    expect(change.detail, 'flat');
    expect(change.isBreaking, isTrue);
  });

  test('a reference to any other definition still compares by name', () {
    String ref(String name) =>
        'https://a2ui.org/specification/v0_9/common_types.json'
        '#/\$defs/$name';
    final changes = genUiCatalogDiff(
      catalogWith(
        properties: {'price': S.combined($ref: ref('DynamicString'))},
      ),
      catalogWith(
        properties: {'price': S.combined($ref: ref('DynamicNumber'))},
      ),
    );

    final GenUiCatalogChange change = changes.singleWhere(
      (change) => change.kind == GenUiCatalogChangeKind.propertyTypeChanged,
    );
    expect(change.isBreaking, isTrue);
    expect(change.detail, contains('DynamicNumber'));
  });
}
