import 'package:genui/genui.dart';

/// The component id A2UI renders a surface from.
const String genUiRootComponentId = 'root';

/// Stands for a template's row index in a resolved path.
///
/// A component inside a template is rendered once per row and reads the same
/// property from each of them, so the path it is bound to is a family rather
/// than a single entry: `/tasks/*/label`, not `/tasks/0/label`.
const String genUiRowWildcard = '*';

/// The shape of a surface the model built: what contains what, and which data
/// model paths each component is bound to.
///
/// Nothing in an app's source says that `/cart/total` is on screen, or that
/// `item_row` sits inside `cart_list`. A model decided both at runtime, in a
/// message that is gone by the time someone reports the bug. This reads that
/// decision back out of the component definitions.
///
/// It also answers two questions that are bugs when the answer is not empty:
/// which components nothing on the surface reaches ([unreachable]), and
/// whether a component contains itself ([cyclic]).
///
/// One caveat on [childrenOf]. A2UI names a child by its id, as a plain
/// string, and the string carries nothing that marks it as an id rather than
/// as text. The catalog's schema is what tells them apart, and in practice it
/// does so by the description on the property, which every catalog is free to
/// write its own way. So this reads a string property as a child when it
/// matches the id of a component on the same surface, which has two
/// consequences worth knowing. A literal that happens to equal an id is drawn
/// as an edge. And a child reference naming a component that was never created
/// is not drawn at all, because nothing distinguishes it from text; it shows
/// up as the hole it leaves on screen, not here.
class GenUiSurfaceGraph {
  GenUiSurfaceGraph._({
    required this.definition,
    required Map<String, Set<String>> children,
    required Map<String, Set<String>> boundPaths,
    required this.order,
    required this.unreachable,
    required this.cyclic,
  }) : _children = children,
       _boundPaths = boundPaths;

  /// Reads the graph out of [definition].
  factory GenUiSurfaceGraph.of(SurfaceDefinition definition) {
    final Set<String> ids = definition.components.keys.toSet();
    final children = <String, Set<String>>{};
    final boundPaths = <String, Set<String>>{};

    // Which of a component's children arrived through a template, and over
    // which list: a templated child reads its properties inside that list's
    // row, so its paths resolve against it rather than against the root.
    final templates = <String, Map<String, String>>{};
    final rawPaths = <String, Set<String>>{};

    for (final Component component in definition.components.values) {
      final found = <String>{};
      final paths = <String>{};
      final repeated = <String, String>{};
      _scan(component.properties, ids, found, paths, repeated);
      children[component.id] = found;
      rawPaths[component.id] = paths;
      if (repeated.isNotEmpty) templates[component.id] = repeated;
    }

    final order = <String>[];
    final seen = <String>{};
    final cyclic = <String>{};
    final onStack = <String>{};
    final bases = <String, String>{genUiRootComponentId: '/'};
    void walk(String id) {
      if (!ids.contains(id)) return;
      if (onStack.contains(id)) {
        cyclic.add(id);
        return;
      }
      if (!seen.add(id)) return;
      order.add(id);
      onStack.add(id);
      final String base = bases[id] ?? '/';
      for (final String child in children[id]!) {
        final String? over = templates[id]?[child];
        // A component reached two ways keeps the first base it was given.
        bases[child] ??= over == null
            ? base
            : '${_resolve(base, over)}/$genUiRowWildcard';
        walk(child);
      }
      onStack.remove(id);
    }

    walk(genUiRootComponentId);

    for (final MapEntry<String, Set<String>> entry in rawPaths.entries) {
      final String base = bases[entry.key] ?? '/';
      boundPaths[entry.key] = <String>{
        for (final String path in entry.value) _resolve(base, path),
      };
    }

    return GenUiSurfaceGraph._(
      definition: definition,
      children: children,
      boundPaths: boundPaths,
      order: List<String>.unmodifiable(order),
      unreachable: Set<String>.unmodifiable(
        ids.where((String id) => !seen.contains(id)).toSet(),
      ),
      cyclic: Set<String>.unmodifiable(cyclic),
    );
  }

  /// The surface this graph was read from.
  final SurfaceDefinition definition;

  final Map<String, Set<String>> _children;
  final Map<String, Set<String>> _boundPaths;

  /// Every component reachable from [genUiRootComponentId], in the order a
  /// depth-first walk of the tree visits them.
  ///
  /// Empty when the surface has no root component, which is the one shape the
  /// renderer refuses outright.
  final List<String> order;

  /// Components the surface defines that nothing reaches from the root.
  ///
  /// They cost tokens to send and render nothing.
  final Set<String> unreachable;

  /// Components that contain themselves, directly or through a descendant.
  final Set<String> cyclic;

  /// Whether the surface has the component the renderer starts from.
  bool get hasRoot => definition.components.containsKey(genUiRootComponentId);

  /// The children of [id], in the order its properties name them.
  Set<String> childrenOf(String id) => _children[id] ?? const <String>{};

  /// The data model paths [id] is bound to, resolved.
  ///
  /// A component inside a template writes its paths relative to the row it
  /// renders, so the paths come back with [genUiRowWildcard] where the row
  /// index goes: a `label` under a template over `/tasks` is `/tasks/*/label`,
  /// which is every row at once and no row in particular. What the message
  /// literally said is still in the component's properties.
  ///
  /// Reading and writing are not separated: an input's value binding is both,
  /// and which one it is depends on the component rather than on the message.
  Set<String> pathsOf(String id) => _boundPaths[id] ?? const <String>{};

  /// How deep [id] sits under the root, or `null` when nothing reaches it.
  int? depthOf(String id) => _depthOf(id, <String>{});

  int? _depthOf(String id, Set<String> walked) {
    if (id == genUiRootComponentId) return 0;
    if (!walked.add(id)) return null;
    for (final MapEntry<String, Set<String>> entry in _children.entries) {
      if (!entry.value.contains(id)) continue;
      final int? parent = _depthOf(entry.key, walked);
      if (parent != null) return parent + 1;
    }
    return null;
  }

  /// Every bound path on the surface, and the components bound to it.
  Map<String, Set<String>> get pathBindings {
    final result = <String, Set<String>>{};
    for (final MapEntry<String, Set<String>> entry in _boundPaths.entries) {
      for (final String path in entry.value) {
        result.putIfAbsent(path, () => <String>{}).add(entry.key);
      }
    }
    return result;
  }

  /// What is worth knowing about the surface, in a line or three.
  String describe() {
    final out = StringBuffer();
    if (!hasRoot) {
      out.writeln(
        '${definition.surfaceId} has no "$genUiRootComponentId" component, so '
        'nothing renders.',
      );
    }
    out.writeln(
      '${order.length} component${order.length == 1 ? '' : 's'} on '
      '${definition.surfaceId}, bound to ${pathBindings.length} '
      'path${pathBindings.length == 1 ? '' : 's'}.',
    );
    if (unreachable.isNotEmpty) {
      out.writeln(
        'Created and never reached: '
        '${(unreachable.toList()..sort()).join(', ')}.',
      );
    }
    if (cyclic.isNotEmpty) {
      out.writeln('Contains itself: ${(cyclic.toList()..sort()).join(', ')}.');
    }
    return out.toString().trimRight();
  }

  /// [path] as the renderer resolves it inside a context rooted at [base].
  ///
  /// The same rule A2UI's own `DataContext` applies: a path starting with `/`
  /// is absolute and escapes the row it was written in, and anything else
  /// hangs off the context it was written in.
  static String _resolve(String base, String path) {
    if (path.startsWith('/')) return path;
    if (path.isEmpty || path == '.') return base;
    final String trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmed/$path';
  }

  static void _scan(
    Object? value,
    Set<String> ids,
    Set<String> children,
    Set<String> paths,
    Map<String, String> templates,
  ) {
    switch (value) {
      case final Map<Object?, Object?> map:
        // A template names both the component it repeats and the list it
        // repeats over, in the same two keys. Take them here and leave them
        // out of the walk below, or the id would be counted twice.
        if (map['componentId'] case final String id) {
          children.add(id);
          if (map['path'] case final String over) {
            templates[id] = over;
            // The list is a binding of the component holding the template
            // too: it watches it to know how many rows there are.
            paths.add(over);
          }
        } else if (map['path'] case final String path) {
          paths.add(path);
        }
        for (final MapEntry<Object?, Object?> entry in map.entries) {
          if (entry.key == 'componentId' || entry.key == 'path') continue;
          _scan(entry.value, ids, children, paths, templates);
        }
      case final List<Object?> list:
        for (final Object? item in list) {
          _scan(item, ids, children, paths, templates);
        }
      case final String text:
        if (ids.contains(text)) children.add(text);
      case _:
        break;
    }
  }
}
