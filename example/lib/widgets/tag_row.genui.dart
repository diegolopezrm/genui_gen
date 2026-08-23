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
  dataSchema: S.object(
    description:
        'A row of short text tags rendered as chips. Exactly one tag '
        'is highlighted as selected. Use it to show categories, '
        'filters or keywords attached to an item.',
    properties: {
      'tags': A2uiSchemas.stringArrayReference(
        description: 'The tags to display, one chip each, in order.',
      ),
      'selectedIndex': A2uiSchemas.numberReference(
        description:
            'The zero-based index of the highlighted tag. Defaults to the '
            'first one.',
      ),
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'TagRow', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'tags': GenUiBinding.stringList(data['tags']),
        'selectedIndex': GenUiBinding.number(data['selectedIndex']),
      },
      builder: (context, v) => TagRow(
        tags:
            v.stringList('tags') ??
            missing<List<String>>('tags', const <String>[]),
        selectedIndex: v.number('selectedIndex')?.toInt() ?? 0,
      ),
    );
  },
);
