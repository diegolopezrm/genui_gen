// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'task_list.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [TaskList].
final CatalogItem taskListCatalogItem = CatalogItem(
  name: 'TaskList',
  schema: S.object(
    description: 'A titled list of rows, one per item in the data.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'The heading above the list.',
      }),
      'rows': S.fromMap({
        ...CommonSchemas.childList.value,
        'description': 'One row per task.',
      }),
      'emptyLabel': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'Shown when there are no rows.',
      }),
    },
    required: ['title', 'rows'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "TaskList",
    "title": "Quarterly report",
    "rows": [
      "child_rows_1",
      "child_rows_2"
    ]
  },
  {
    "id": "child_rows_1",
    "component": "Text",
    "text": "Sample rows 1"
  },
  {
    "id": "child_rows_2",
    "component": "Text",
    "text": "Sample rows 2"
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'TaskList', property);
      return fallback;
    }

    return TaskList(
      title:
          genUiAsString(props.value('title')) ?? missing<String>('title', ''),
      rows: props.value('rows') is List
          ? [for (final child in props.children('rows')) buildChild(child)]
          : missing<List<Widget>>('rows', const <Widget>[]),
      emptyLabel:
          genUiAsString(props.value('emptyLabel')) ?? 'Nothing here yet.',
    );
  },
);
