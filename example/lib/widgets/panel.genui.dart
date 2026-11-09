// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'panel.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [Panel].
final CatalogItem panelCatalogItem = CatalogItem(
  name: 'Panel',
  schema: S.object(
    description:
        'A titled panel that wraps any other component. It has a '
        'header with the title and a close button, a body and an '
        'optional row of action components (typically buttons) along '
        'the bottom edge. Use it to group related content under a '
        'heading.',
    properties: {
      'title': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'The heading shown at the top of the panel.',
      }),
      'child': S.fromMap({
        ...CommonSchemas.componentId.value,
        'description': 'The component rendered as the body of the panel.',
      }),
      'actions': S.list(
        description:
            'Components laid out along the bottom edge, usually buttons.',
        items: CommonSchemas.componentId,
      ),
      'onClose': S.fromMap({
        ...CommonSchemas.action.value,
        'description':
            'Fired when the user presses the close button in the header.',
      }),
      'meta': S.combined(
        description:
            'Extra labelled details, shown under the title. The keys are '
            'the agent\'s to choose: this is for whatever it decided was '
            'worth attaching to this particular panel, which is exactly '
            'the case a fixed set of properties cannot express.',
        anyOf: [
          S.object(additionalProperties: S.string()),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    },
    required: ['title', 'child'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "Panel",
    "title": "Quarterly report",
    "child": "child_child",
    "actions": [
      "child_actions_1",
      "child_actions_2"
    ],
    "onClose": {
      "event": {
        "name": "panel_closed"
      }
    }
  },
  {
    "id": "child_child",
    "component": "Text",
    "text": "Sample child"
  },
  {
    "id": "child_actions_1",
    "component": "Text",
    "text": "Sample actions 1"
  },
  {
    "id": "child_actions_2",
    "component": "Text",
    "text": "Sample actions 2"
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'Panel', property);
      return fallback;
    }

    return Panel(
      title:
          genUiAsString(props.value('title')) ?? missing<String>('title', ''),
      child: switch (props.child('child')) {
        final child? => buildChild(child),
        _ => missing<Widget>('child', const SizedBox.shrink()),
      },
      actions: props.value('actions') is List
          ? [for (final child in props.children('actions')) buildChild(child)]
          : const [],
      onClose: genUiActionHandler(props.action('onClose')),
      meta: genUiAsStringMap(props.value('meta')) ?? const <String, String>{},
    );
  },
);
