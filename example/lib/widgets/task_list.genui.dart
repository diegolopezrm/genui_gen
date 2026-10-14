// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'task_list.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [ComponentImplementation] for [TaskList].
final ComponentImplementation taskListCatalogItem = ComponentImplementation(
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
  builder: (context, node, props, buildChild) => TaskList(
    title: props.string('title') ?? '',
    rows: props.children('rows').map(buildChild).toList(),
    emptyLabel: props.string('emptyLabel') ?? 'Nothing here yet.',
  ),
);
