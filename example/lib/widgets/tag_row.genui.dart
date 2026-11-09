// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'tag_row.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [TagRow].
final CatalogItem tagRowCatalogItem = CatalogItem(
  name: 'TagRow',
  schema: S.object(
    description:
        'A row of short text tags rendered as chips. Exactly one tag '
        'is highlighted as selected. Use it to show categories, '
        'filters or keywords attached to an item.',
    properties: {
      'tags': S.fromMap({
        ...CommonSchemas.dynamicStringList.value,
        'description': 'The tags to display, one chip each, in order.',
      }),
      'selectedIndex': S.fromMap({
        ...CommonSchemas.dynamicNumber.value,
        'description':
            'The zero-based index of the highlighted tag. Defaults to the '
            'first one.',
      }),
    },
    required: ['tags'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "TagRow",
    "tags": [
      "Alpha",
      "Beta"
    ]
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'TagRow', property);
      return fallback;
    }

    return TagRow(
      tags:
          genUiAsStringList(props.value('tags')) ??
          missing<List<String>>('tags', const <String>[]),
      selectedIndex: genUiAsNum(props.value('selectedIndex'))?.toInt() ?? 0,
    );
  },
);
