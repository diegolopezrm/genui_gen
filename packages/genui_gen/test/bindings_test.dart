import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'src/surface.dart';

/// Every shape of property the generator emits, with the schema it emits for
/// it. The renderer decides how to resolve a property from its schema, so
/// this is what decides whether a `{"path": ...}` reaches the widget as a
/// value.
final Map<String, Schema> _properties = <String, Schema>{
  'text': CommonSchemas.dynamicString,
  'count': CommonSchemas.dynamicNumber,
  'on': CommonSchemas.dynamicBoolean,
  'tags': CommonSchemas.dynamicStringList,
  'tone': S.combined(
    anyOf: [
      S.string(enumValues: ['warm', 'cold']),
      CommonSchemas.dataBinding,
      CommonSchemas.functionCall,
    ],
  ),
  'sizes': S.combined(
    anyOf: [
      S.list(items: S.number()),
      CommonSchemas.dataBinding,
      CommonSchemas.functionCall,
    ],
  ),
  'row': S.combined(
    anyOf: [
      S.object(properties: {'label': S.string(), 'value': S.number()}),
      CommonSchemas.dataBinding,
      CommonSchemas.functionCall,
    ],
  ),
  'rows': S.combined(
    anyOf: [
      S.list(items: S.object(properties: {'label': S.string()})),
      CommonSchemas.dataBinding,
      CommonSchemas.functionCall,
    ],
  ),
  'labels': S.combined(
    anyOf: [
      S.object(additionalProperties: S.string()),
      CommonSchemas.dataBinding,
      CommonSchemas.functionCall,
    ],
  ),
};

/// What the last build read, with the coercions generated code applies.
Map<String, Object?> _read = <String, Object?>{};
int _builds = 0;

final CatalogItem _probe = CatalogItem(
  name: 'Probe',
  schema: S.object(properties: _properties),
  builder: (context, node, props, buildChild) {
    _builds++;
    _read = <String, Object?>{
      'text': genUiAsString(props.value('text')),
      'count': genUiAsNum(props.value('count')),
      'on': genUiAsBool(props.value('on')),
      'tags': genUiAsStringList(props.value('tags')),
      'tone': genUiAsString(props.value('tone')),
      'sizes': genUiAsNumList(props.value('sizes')),
      'row': genUiAsObject(props.value('row')),
      'rows': genUiAsObjectList(props.value('rows')),
      'labels': genUiAsStringMap(props.value('labels')),
    };
    return const SizedBox(width: 10, height: 10);
  },
);

const Map<String, Object?> _literals = <String, Object?>{
  'text': 'hello',
  'count': 3,
  'on': true,
  'tags': ['a', 'b'],
  'tone': 'cold',
  'sizes': [1, 2.5],
  'row': {'label': 'Revenue', 'value': 10},
  'rows': [
    {'label': 'One'},
    {'label': 'Two'},
  ],
  'labels': {'en': 'Hello'},
};

void main() {
  setUp(() {
    _read = <String, Object?>{};
    _builds = 0;
  });

  testWidgets('every property shape takes a literal', (tester) async {
    final rendered = await renderSurface(
      tester,
      items: [_probe],
      components: [
        {'id': 'root', 'component': 'Probe', ..._literals},
      ],
    );

    expect(rendered.errors, isEmpty);
    expect(_read, _literals);
  });

  testWidgets('every property shape takes a {"path": ...} binding', (
    tester,
  ) async {
    final rendered = await renderSurface(
      tester,
      items: [_probe],
      data: <String, Object?>{'probe': _literals},
      components: [
        {
          'id': 'root',
          'component': 'Probe',
          for (final String key in _literals.keys) key: {'path': '/probe/$key'},
        },
      ],
    );

    expect(rendered.errors, isEmpty);
    expect(_read, _literals);
  });

  testWidgets('a binding coerces the way the generated code says', (
    tester,
  ) async {
    // The model put a number where a string was declared, a numeric string
    // where a number was, and junk inside a list: nothing throws, and what can
    // be read is.
    await renderSurface(
      tester,
      items: [_probe],
      data: <String, Object?>{
        'probe': <String, Object?>{
          'text': 42,
          'count': '7.5',
          'tags': ['a', null, 3],
          'rows': [
            {'label': 'One'},
            'not a row',
          ],
        },
      },
      components: [
        {
          'id': 'root',
          'component': 'Probe',
          for (final String key in ['text', 'count', 'tags', 'rows'])
            key: {'path': '/probe/$key'},
        },
      ],
    );

    expect(_read['text'], '42');
    expect(_read['count'], 7.5);
    expect(_read['tags'], ['a', '3']);
    expect(_read['rows'], [
      {'label': 'One'},
    ]);
  });

  testWidgets('a binding that resolves to nothing reads as null', (
    tester,
  ) async {
    await renderSurface(
      tester,
      items: [_probe],
      components: [
        {
          'id': 'root',
          'component': 'Probe',
          'text': {'path': '/missing'},
          'row': {'path': '/missing'},
        },
      ],
    );

    expect(_read['text'], isNull);
    expect(_read['row'], isNull);
  });

  testWidgets('the component rebuilds when a bound value changes', (
    tester,
  ) async {
    final rendered = await renderSurface(
      tester,
      items: [_probe],
      data: <String, Object?>{'text': 'before'},
      components: [
        {
          'id': 'root',
          'component': 'Probe',
          'text': {'path': '/text'},
        },
      ],
    );
    expect(_read['text'], 'before');
    final int builds = _builds;

    rendered.surface.dataModel.set('/text', 'after');
    await tester.pump();

    expect(_read['text'], 'after');
    expect(_builds, greaterThan(builds));
  });

  testWidgets('a {"call": ...} is answered by the catalog', (tester) async {
    await renderSurface(
      tester,
      items: [_probe],
      functions: [
        GenUiClientFunction(
          name: 'shout',
          description: 'Upper-cases a string.',
          argumentSchema: S.object(
            properties: {'value': CommonSchemas.dynamicString},
          ),
          body: (args, context) => '${args['value']}'.toUpperCase(),
        ),
      ],
      data: <String, Object?>{'name': 'ada'},
      components: [
        {
          'id': 'root',
          'component': 'Probe',
          'text': {
            'call': 'shout',
            'args': {
              'value': {'path': '/name'},
            },
          },
        },
      ],
    );

    expect(_read['text'], 'ADA');
  });

  testWidgets('a relative path resolves inside a template row', (tester) async {
    await renderSurface(
      tester,
      items: [_probe],
      data: <String, Object?>{
        'items': [
          {'label': 'only row'},
        ],
      },
      components: [
        {
          'id': 'root',
          'component': 'Column',
          'children': {'componentId': 'row', 'path': '/items'},
        },
        {
          'id': 'row',
          'component': 'Probe',
          'text': {'path': 'label'},
        },
      ],
    );

    expect(_read['text'], 'only row');
  });
}
