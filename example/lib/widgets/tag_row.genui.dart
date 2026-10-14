// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'tag_row.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [ComponentImplementation] for [TagRow].
final ComponentImplementation tagRowCatalogItem = ComponentImplementation(
  name: 'TagRow',
  schema: GenUiSchemas.component(
    description:
        'A row of short text tags rendered as chips. Exactly one tag '
        'is highlighted as selected. Use it to show categories, '
        'filters or keywords attached to an item.',
    properties: {
      'tags': GenUiSchemas.stringList(
        description: 'The tags to display, one chip each, in order.',
      ),
      'selectedIndex': GenUiSchemas.number(
        description:
            'The zero-based index of the highlighted tag. Defaults to the '
            'first one.',
      ),
    },
    required: ['tags'],
  ),
  builder: (context, node, props, buildChild) => TagRow(
    tags: genUiAsStringList(props.value('tags')) ?? const <String>[],
    selectedIndex: props.number('selectedIndex')?.toInt() ?? 0,
  ),
);
