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
  dataSchema: S.object(
    description:
        'A titled panel that wraps any other component. It has a '
        'header with the title and a close button, a body and an '
        'optional row of action components (typically buttons) along '
        'the bottom edge. Use it to group related content under a '
        'heading.',
    properties: {
      'title': A2uiSchemas.stringReference(
        description: 'The heading shown at the top of the panel.',
      ),
      'child': A2uiSchemas.componentReference(
        description: 'The component rendered as the body of the panel.',
      ),
      'actions': S.list(
        description:
            'Components laid out along the bottom edge, usually buttons.',
        items: A2uiSchemas.componentReference(),
      ),
      'onClose': A2uiSchemas.action(
        description:
            'Fired when the user presses the close button in the header.',
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
    "title": "Sample title",
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'Panel', property);
      return fallback;
    }

    final _child = data['child'];
    final _actions = data['actions'];
    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {'title': GenUiBinding.string(data['title'])},
      builder: (context, v) => Panel(
        title: v.string('title') ?? missing<String>('title', ''),
        child: _child is String
            ? ctx.buildChild(_child)
            : missing<Widget>('child', const SizedBox.shrink()),
        actions: _actions is List
            ? _actions
                  .whereType<String>()
                  .map((id) => ctx.buildChild(id))
                  .toList()
            : const [],
        onClose: genUiActionHandler(ctx, data['onClose']),
      ),
    );
  },
);
