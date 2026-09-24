import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// The path a child template reads from, in the shape a binding takes, or
/// `null` when [reference] is a plain list of component ids.
///
/// A2UI describes the children of a component in two ways: a list of ids the
/// agent wrote out, or a template — `{"componentId": "row", "path": "/rows"}`
/// — that is repeated once per entry of the data model. The second is what
/// makes a list that grows when the agent sends new data instead of a new
/// surface, and it is the only one of the two that needs a binding.
Object? genUiTemplatePath(Object? reference) {
  if (reference is Map &&
      reference['componentId'] is String &&
      reference['path'] is String) {
    return <String, Object?>{'path': reference['path']};
  }
  return null;
}

/// The children [reference] describes.
///
/// [resolved] is what the path holds, for a template; it is ignored for a
/// plain list of ids. Both a list and a map are accepted, because both are
/// things an agent puts at a path, and the key of each entry becomes part of
/// the child's own data context: the child of `/rows` at index 2 reads its
/// properties from `/rows/2`, so a template component can bind to `title`
/// and mean "the title of my row".
List<Widget> genUiTemplateChildren(
  CatalogItemContext ctx,
  Object? reference,
  Object? resolved,
) {
  if (reference is List) {
    return <Widget>[
      for (final Object? id in reference)
        if (id is String) ctx.buildChild(id),
    ];
  }

  if (reference is! Map) return const <Widget>[];
  final Object? componentId = reference['componentId'];
  final Object? path = reference['path'];
  if (componentId is! String || path is! String) return const <Widget>[];

  final List<String> keys = switch (resolved) {
    final List<Object?> list => <String>[
      for (var i = 0; i < list.length; i++) '$i',
    ],
    final Map<Object?, Object?> map => <String>[
      for (final Object? key in map.keys) '$key',
    ],
    _ => const <String>[],
  };

  return <Widget>[
    for (final String key in keys)
      KeyedSubtree(
        // Keyed by the entry rather than by position, so that a row removed
        // from the middle takes its state with it instead of handing it to
        // the row that moved up.
        key: ValueKey<String>('$path/$key'),
        child: ctx.buildChild(
          componentId,
          ctx.dataContext.nested(DataPath('$path/$key')),
        ),
      ),
  ];
}
