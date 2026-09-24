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
  dataSchema: S.object(
    description: 'A titled list of rows, one per item in the data.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'The heading above the list.',
      ),
      'rows': A2uiSchemas.componentArrayReference(
        description: 'One row per task.',
      ),
      'emptyLabel': A2uiSchemas.stringReference(
        description: 'Shown when there are no rows.',
      ),
    },
    required: ['title', 'rows'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "TaskList",
    "title": "Sample title",
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'TaskList', property);
      return fallback;
    }

    final _rows = data['rows'];
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'title': GenUiBinding.string(data['title']),
        'rows': GenUiBinding.value(genUiTemplatePath(data['rows'])),
        'emptyLabel': GenUiBinding.string(data['emptyLabel']),
      },
      builder: (context, v) => TaskList(
        title: v.string('title') ?? missing<String>('title', ''),
        rows: genUiTemplateChildren(ctx, _rows, v.raw('rows')),
        emptyLabel: v.string('emptyLabel') ?? 'Nothing here yet.',
      ),
    );
  },
);
