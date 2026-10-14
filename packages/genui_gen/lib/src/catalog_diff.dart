/// What changed between two versions of a catalog, seen from where it
/// matters: the model that composes against it.
///
/// A catalog is a contract with something that cannot be recompiled. Renaming
/// a property or dropping an enum value does not break the app — the app is
/// where the change was made — it breaks the agent, whose prompt and few-shot
/// examples still describe yesterday's components, and it breaks quietly, in
/// production, one malformed message at a time.
enum GenUiCatalogChangeKind {
  /// A component the catalog did not have before.
  componentAdded(breaking: false),

  /// A component that is gone. An agent that still asks for it gets nothing.
  componentRemoved(breaking: true),

  /// A property that can be left out.
  propertyAdded(breaking: false),

  /// A property that is gone. A message that still carries it is rejected by
  /// a catalog that declares `unevaluatedProperties: false`.
  propertyRemoved(breaking: true),

  /// A property the model now has to send.
  propertyBecameRequired(breaking: true),

  /// A property the model no longer has to send.
  propertyBecameOptional(breaking: false),

  /// A property whose type changed under the same name, which is the change a
  /// model is least likely to survive: it keeps sending what it learned.
  propertyTypeChanged(breaking: true),

  /// A value the model may now send for an enumerated property.
  enumValueAdded(breaking: false),

  /// A value the model may no longer send.
  enumValueRemoved(breaking: true),

  /// The prose the model reads about a component or a property.
  ///
  /// Not breaking, and not nothing: the description is the instruction. A
  /// reworded property changes what the model does with it.
  descriptionChanged(breaking: false),

  /// The id a surface names when it is created against this catalog.
  catalogIdChanged(breaking: true);

  const GenUiCatalogChangeKind({required this.breaking});

  /// Whether a message composed against the old catalog can still be wrong
  /// after this change.
  final bool breaking;
}

/// One difference between two catalogs.
class GenUiCatalogChange {
  /// Creates a [GenUiCatalogChange].
  const GenUiCatalogChange(this.kind, {required this.where, this.detail});

  /// What kind of change it is.
  final GenUiCatalogChangeKind kind;

  /// Where it is: `ProductCard`, `ProductCard.price`, or the catalog itself.
  final String where;

  /// What changed, when saying so needs more than the kind.
  final String? detail;

  /// Whether a message composed against the old catalog can still be wrong.
  bool get isBreaking => kind.breaking;

  @override
  String toString() =>
      '${isBreaking ? 'BREAKING' : 'ok      '} $where: ${kind.name}'
      '${detail == null ? '' : ' ($detail)'}';
}

/// Every difference between two catalog documents, in the order a reader
/// wants them: breaking first, then by where.
///
/// Both arguments are the JSON that `genUiCatalogJson` produces.
///
/// ```dart
/// test('the catalog has not broken the agent', () {
///   final changes = genUiCatalogDiff(
///     jsonDecode(File('catalog.json').readAsStringSync()) as Map<String, Object?>,
///     genUiCatalogJson(genUiCatalog),
///   );
///
///   expect(
///     changes.where((change) => change.isBreaking),
///     isEmpty,
///     reason: changes.join('\n'),
///   );
/// });
/// ```
List<GenUiCatalogChange> genUiCatalogDiff(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final changes = <GenUiCatalogChange>[];

  if (before['catalogId'] != after['catalogId']) {
    changes.add(
      GenUiCatalogChange(
        GenUiCatalogChangeKind.catalogIdChanged,
        where: 'catalog',
        detail: '${before['catalogId']} -> ${after['catalogId']}',
      ),
    );
  }

  final Map<String, Object?> oldComponents = _components(before);
  final Map<String, Object?> newComponents = _components(after);

  for (final name in <String>{...oldComponents.keys, ...newComponents.keys}) {
    final Object? oldComponent = oldComponents[name];
    final Object? newComponent = newComponents[name];
    if (oldComponent == null) {
      changes.add(
        GenUiCatalogChange(GenUiCatalogChangeKind.componentAdded, where: name),
      );
      continue;
    }
    if (newComponent == null) {
      changes.add(
        GenUiCatalogChange(
          GenUiCatalogChangeKind.componentRemoved,
          where: name,
        ),
      );
      continue;
    }
    changes.addAll(
      _componentChanges(
        name,
        (oldComponent as Map).cast<String, Object?>(),
        (newComponent as Map).cast<String, Object?>(),
      ),
    );
  }

  changes.sort((a, b) {
    if (a.isBreaking != b.isBreaking) return a.isBreaking ? -1 : 1;
    return a.where.compareTo(b.where);
  });
  return changes;
}

List<GenUiCatalogChange> _componentChanges(
  String name,
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final changes = <GenUiCatalogChange>[];

  final Map<String, Object?> oldProperties = _properties(before);
  final Map<String, Object?> newProperties = _properties(after);
  final Set<String> oldRequired = _required(before);
  final Set<String> newRequired = _required(after);

  for (final property in <String>{
    ...oldProperties.keys,
    ...newProperties.keys,
  }) {
    // `component` is the discriminator, written by the generator from the
    // component's own name, and `id` is the protocol's. Neither can change
    // without the component changing. genui leaves `id` to a shared
    // definition and a2ui_core lists it, so it would otherwise read as new.
    if (property == 'component' || property == 'id') continue;
    final String where = '$name.$property';
    final Object? oldProperty = oldProperties[property];
    final Object? newProperty = newProperties[property];

    if (oldProperty == null) {
      changes.add(
        GenUiCatalogChange(
          newRequired.contains(property)
              ? GenUiCatalogChangeKind.propertyBecameRequired
              : GenUiCatalogChangeKind.propertyAdded,
          where: where,
          detail: newRequired.contains(property) ? 'new and required' : null,
        ),
      );
      continue;
    }
    if (newProperty == null) {
      changes.add(
        GenUiCatalogChange(
          GenUiCatalogChangeKind.propertyRemoved,
          where: where,
        ),
      );
      continue;
    }

    final Map<String, Object?> oldMap = (oldProperty as Map)
        .cast<String, Object?>();
    final Map<String, Object?> newMap = (newProperty as Map)
        .cast<String, Object?>();

    if (oldRequired.contains(property) != newRequired.contains(property)) {
      changes.add(
        GenUiCatalogChange(
          newRequired.contains(property)
              ? GenUiCatalogChangeKind.propertyBecameRequired
              : GenUiCatalogChangeKind.propertyBecameOptional,
          where: where,
        ),
      );
    }

    final String? oldShape = _shape(oldMap);
    final String? newShape = _shape(newMap);
    if (oldShape != newShape) {
      changes.add(
        GenUiCatalogChange(
          GenUiCatalogChangeKind.propertyTypeChanged,
          where: where,
          detail: '$oldShape -> $newShape',
        ),
      );
    }

    changes.addAll(_enumChanges(where, oldMap, newMap));

    if (oldMap['description'] != newMap['description']) {
      changes.add(
        GenUiCatalogChange(
          GenUiCatalogChangeKind.descriptionChanged,
          where: where,
        ),
      );
    }
  }

  if (_description(before) != _description(after)) {
    changes.add(
      GenUiCatalogChange(
        GenUiCatalogChangeKind.descriptionChanged,
        where: name,
      ),
    );
  }

  return changes;
}

/// A component's description, which genui writes on its own `allOf` branch
/// and a2ui_core on the component.
Object? _description(Map<String, Object?> component) =>
    _own(component)['description'] ?? component['description'];

List<GenUiCatalogChange> _enumChanges(
  String where,
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final Set<String> oldValues = _enumValues(before);
  final Set<String> newValues = _enumValues(after);
  return <GenUiCatalogChange>[
    for (final value in newValues.difference(oldValues))
      GenUiCatalogChange(
        GenUiCatalogChangeKind.enumValueAdded,
        where: where,
        detail: value,
      ),
    for (final value in oldValues.difference(newValues))
      GenUiCatalogChange(
        GenUiCatalogChangeKind.enumValueRemoved,
        where: where,
        detail: value,
      ),
  ];
}

Map<String, Object?> _components(Map<String, Object?> catalog) =>
    (catalog['components'] as Map?)?.cast<String, Object?>() ??
    const <String, Object?>{};

/// A component's own properties, which live in the last branch of its `allOf`;
/// the branches before it are the shared `$ref`s every component carries.
Map<String, Object?> _own(Map<String, Object?> component) {
  final Object? allOf = component['allOf'];
  if (allOf is List && allOf.isNotEmpty && allOf.last is Map) {
    return (allOf.last as Map).cast<String, Object?>();
  }
  return component;
}

Map<String, Object?> _properties(Map<String, Object?> component) =>
    (_own(component)['properties'] as Map?)?.cast<String, Object?>() ??
    const <String, Object?>{};

Set<String> _required(Map<String, Object?> component) => <String>{
  for (final name in (_own(component)['required'] as List?) ?? const [])
    '$name',
};

/// The enum values a property declares, at any depth.
///
/// A generated enum property offers its names next to a data binding and a
/// function call, so they are not at the top. A `$ref` is not followed: a
/// shared definition's enums, such as a function call's `returnType`, are not
/// the property's.
Set<String> _enumValues(Map<String, Object?> property) {
  final found = <String>{};
  void walk(Object? node) {
    if (node is List) {
      node.forEach(walk);
      return;
    }
    if (node is! Map || node[r'$ref'] != null) return;
    for (final key in const ['enum', 'enumValues']) {
      for (final value in (node[key] as List?) ?? const []) {
        found.add('$value');
      }
    }
    for (final Object? child in node.values) {
      walk(child);
    }
  }

  walk(property);
  return found;
}

/// Definitions in A2UI's `common_types.json` that are a JSON type and nothing
/// more, by name.
///
/// A property may name one of these by `$ref` or spell the type out, and both
/// accept exactly the same values. genui spells a child's id as a string;
/// a2ui_flutter points at `ComponentId`. Without this, moving a catalog from
/// one to the other would report every child as a breaking change. The other
/// definitions carry structure of their own and still compare by name.
const Map<String, String> _plainCommonTypes = <String, String>{
  'ComponentId': 'string',
  // genui spelled these out where a2ui_core names them.
  'ChildList': 'oneOf(array|object)',
  'DynamicStringList': 'oneOf(DataBinding|FunctionCall|array)',
};

/// The shared definitions a union of a literal, a data binding and a function
/// call amounts to, by the shape of the union.
///
/// a2ui_core writes a dynamic enum, or a dynamic value with a description of
/// its own, as that union spelled out; genui named the shared definition.
const Map<String, String> _dynamicUnions = <String, String>{
  'oneOf(DataBinding|FunctionCall|string)': 'DynamicString',
  'oneOf(DataBinding|FunctionCall|number)': 'DynamicNumber',
  'oneOf(DataBinding|FunctionCall|boolean)': 'DynamicBoolean',
};

const String _commonTypeDefs = r'common_types.json#/$defs/';
const String _localDefs = r'#/$defs/';

/// The name of the shared definition [ref] points at, or `null` when it
/// points anywhere else.
///
/// genui points into `common_types.json`; a2ui_core's catalog document carries
/// the shared definitions in its own `$defs` and points there. Both name the
/// same definition, so both reduce to its name.
String? _commonTypeName(String ref) {
  final int at = ref.indexOf(_commonTypeDefs);
  if (at >= 0) return ref.substring(at + _commonTypeDefs.length);
  if (ref.startsWith(_localDefs)) return ref.substring(_localDefs.length);
  return null;
}

/// What a property accepts, reduced to something two versions can be compared
/// by: its type, or the set of shapes a `oneOf` or an `anyOf` offers.
String? _shape(Map<String, Object?> property) {
  if (property['type'] case final Object type) {
    // genui spells a data binding and a function call out inline, where
    // a2ui_core points at the shared definitions.
    if (type == 'object') {
      if (property['properties'] case final Map props) {
        if (props.containsKey('path') && !props.containsKey('componentId')) {
          return 'DataBinding';
        }
        if (props.containsKey('call')) return 'FunctionCall';
      }
    }
    return '$type';
  }
  if (property[r'$ref'] case final Object ref) {
    final String target = '$ref';
    final String? name = _commonTypeName(target);
    if (name == null) return target;
    return _plainCommonTypes[name] ?? name;
  }
  for (final keyword in const ['oneOf', 'anyOf']) {
    if (property[keyword] case final List branches) {
      final shapes = <String>[
        for (final branch in branches)
          if (branch is Map)
            _shape(branch.cast<String, Object?>()) ?? 'object'
          else
            '$branch',
      ]..sort();
      final shape = 'oneOf(${shapes.join('|')})';
      return _dynamicUnions[shape] ?? shape;
    }
  }
  // genui writes a dynamic enum as the shared definition narrowed by its
  // names; the definition is the shape.
  if (property['allOf'] case final List branches) {
    for (final branch in branches) {
      if (branch is! Map) continue;
      final String? shape = _shape(branch.cast<String, Object?>());
      if (shape != null) return shape;
    }
  }
  if (property['const'] != null) return 'const';
  return null;
}
