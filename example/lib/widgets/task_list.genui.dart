// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'task_list.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [GenUiComponent] for [TaskList].
final GenUiComponent taskListCatalogItem = GenUiComponent(
  name: 'TaskList',
  schema: GenUiSchemas.component(
    description: 'A titled list of rows, one per item in the data.',
    properties: {
      'title': GenUiSchemas.string(description: 'The heading above the list.'),
      'rows': GenUiSchemas.childList(description: 'One row per task.'),
      'emptyLabel': GenUiSchemas.string(
        description: 'Shown when there are no rows.',
      ),
    },
    required: ['title', 'rows'],
  ),
  examples: [
    r'''
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
  builder: (context, node, props, buildChild) => TaskList(
    title: props.string('title') ?? '',
    rows: props.children('rows').map(buildChild).toList(),
    emptyLabel: props.string('emptyLabel') ?? 'Nothing here yet.',
  ),
);
