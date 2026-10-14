// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'panel.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [GenUiComponent] for [Panel].
final GenUiComponent panelCatalogItem = GenUiComponent(
  name: 'Panel',
  schema: GenUiSchemas.component(
    description:
        'A titled panel that wraps any other component. It has a '
        'header with the title and a close button, a body and an '
        'optional row of action components (typically buttons) along '
        'the bottom edge. Use it to group related content under a '
        'heading.',
    properties: {
      'title': GenUiSchemas.string(
        description: 'The heading shown at the top of the panel.',
      ),
      'child': GenUiSchemas.componentId(
        description: 'The component rendered as the body of the panel.',
      ),
      'actions': GenUiSchemas.componentIdList(
        description:
            'Components laid out along the bottom edge, usually buttons.',
      ),
      'onClose': GenUiSchemas.action(
        description:
            'Fired when the user presses the close button in the header.',
      ),
      'meta': GenUiSchemas.object(
        description:
            'Extra labelled details, shown under the title. The keys are '
            'the agent\'s to choose: this is for whatever it decided was '
            'worth attaching to this particular panel, which is exactly '
            'the case a fixed set of properties cannot express.',
        literal: S.object(additionalProperties: S.string()),
      ),
    },
    required: ['title', 'child'],
  ),
  examples: [
    r'''
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
  builder: (context, node, props, buildChild) => Panel(
    title: props.string('title') ?? '',
    child: switch (props.child('child')) {
      final childNode? => buildChild(childNode),
      null => const SizedBox.shrink(),
    },
    actions: props['actions'] == null
        ? const []
        : props.children('actions').map(buildChild).toList(),
    onClose: props.action('onClose'),
    meta: genUiAsStringMap(props.value('meta')) ?? const <String, String>{},
  ),
);
