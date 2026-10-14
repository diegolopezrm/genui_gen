import 'package:a2ui_core/a2ui_core.dart';

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
/// It also answers three questions that are bugs when the answer is not
/// empty: which components nothing on the surface reaches ([unreachable]),
/// whether a component contains itself ([cyclic]), and which child references
/// name a component the surface does not have ([dangling]).
///
/// The children of a component are the ones its catalog's schema marks as
/// children, which a2ui_core reads the same way when it renders the surface.
/// A component whose type its catalog does not hold has no schema to read, so
/// for it a string property counts as a child when it matches the id of a
/// component on the same surface, and a reference it makes to a missing
/// component cannot be told from text.
class GenUiSurfaceGraph {
  GenUiSurfaceGraph._({
    required this.surface,
    required Map<String, Set<String>> children,
    required Map<String, Set<String>> boundPaths,
    required this.order,
    required this.unreachable,
    required this.cyclic,
    required this.dangling,
  }) : _children = children,
       _boundPaths = boundPaths;

  /// Reads the graph out of [surface].
  factory GenUiSurfaceGraph.of(SurfaceModel<ComponentApi> surface) {
    final Set<String> ids = surface.componentsModel.keys.toSet();
    final children = <String, Set<String>>{};
    final boundPaths = <String, Set<String>>{};

    // Which of a component's children arrived through a template, and over
    // which list: a templated child reads its properties inside that list's
    // row, so its paths resolve against it rather than against the root.
    final templates = <String, Map<String, String>>{};
    final rawPaths = <String, Set<String>>{};

    final dangling = <String, Set<String>>{};

    for (final ComponentModel component in surface.componentsModel.values) {
      final found = <String>{};
      final paths = <String>{};
      final repeated = <String, String>{};
      final RefFields? refs = _refFieldsOf(surface, component);
      // With the schema to go by, text is never read as an id; without it,
      // a string that matches one is the best evidence there is.
      _scan(
        component.properties,
        refs == null ? ids : const <String>{},
        found,
        paths,
        repeated,
      );
      if (refs != null) {
        for (final MapEntry<String, RefKind> field in refs.entries) {
          _collect(component.properties[field.key], field.value, found);
        }
        final Set<String> missing = found.difference(ids);
        if (missing.isNotEmpty) dangling[component.id] = missing;
      }
      children[component.id] = found.intersection(ids);
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
      surface: surface,
      children: children,
      boundPaths: boundPaths,
      order: List<String>.unmodifiable(order),
      unreachable: Set<String>.unmodifiable(
        ids.where((String id) => !seen.contains(id)).toSet(),
      ),
      cyclic: Set<String>.unmodifiable(cyclic),
      dangling: Map<String, Set<String>>.unmodifiable({
        for (final MapEntry<String, Set<String>> entry in dangling.entries)
          entry.key: Set<String>.unmodifiable(entry.value),
      }),
    );
  }

  /// The surface this graph was read from.
  final SurfaceModel<ComponentApi> surface;

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

  /// The child references that name a component the surface does not have,
  /// by the id of the component making them.
  ///
  /// a2ui_flutter draws a placeholder where such a child should be, and
  /// replaces it if the component arrives later, so on a surface still being
  /// built this is what has not come yet; on a finished one it is a hole.
  final Map<String, Set<String>> dangling;

  /// Whether the surface has the component the renderer starts from.
  bool get hasRoot => surface.componentsModel.has(genUiRootComponentId);

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
        '${surface.id} has no "$genUiRootComponentId" component, so '
        'nothing renders.',
      );
    }
    out.writeln(
      '${order.length} component${order.length == 1 ? '' : 's'} on '
      '${surface.id}, bound to ${pathBindings.length} '
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
    if (dangling.isNotEmpty) {
      final List<String> holders = dangling.keys.toList()..sort();
      out.writeln(
        'Names components that do not exist: ${[for (final String holder in holders) '${(dangling[holder]!.toList()..sort()).join(', ')} (in $holder)'].join('; ')}.',
      );
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

  /// The child references [component]'s catalog declares, or `null` when
  /// its catalog cannot be resolved or does not hold its type.
  static RefFields? _refFieldsOf(
    SurfaceModel<ComponentApi> surface,
    ComponentModel component,
  ) {
    final Catalog<ComponentApi, FunctionImplementation> catalog;
    try {
      catalog = surface.resolveCatalog(component.catalog);
    } on A2uiError {
      return null;
    }
    if (!catalog.components.containsKey(component.type)) return null;
    return catalog.refMap.fieldsFor(component.type);
  }

  /// Adds the ids [value] names as [kind] of reference to [found].
  ///
  /// A template's id is left to [_scan], which also records the list it
  /// repeats over.
  static void _collect(Object? value, RefKind kind, Set<String> found) {
    switch (kind) {
      case SingleRef():
        if (value is String) found.add(value);
      case ListRef():
        if (value is List) found.addAll(value.whereType<String>());
      case NestedRef(:final fields, :final includesIds):
        if (value is! List) return;
        for (final Object? item in value) {
          if (item is String && includesIds) found.add(item);
          if (item is! Map) continue;
          for (final MapEntry<String, RefKind> field in fields.entries) {
            _collect(item[field.key], field.value, found);
          }
        }
    }
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
