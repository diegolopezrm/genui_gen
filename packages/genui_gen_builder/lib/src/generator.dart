import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'emitter.dart';
import 'imports.dart';
import 'spec.dart';
import 'strings.dart';
import 'type_mapping.dart';

/// Matches `@GenUiWidget` from `package:genui_gen`.
const genUiWidgetChecker = TypeChecker.typeNamedLiterally(
  'GenUiWidget',
  inPackage: 'genui_gen',
);

/// Matches `@GenUiProp` from `package:genui_gen`.
const genUiPropChecker = TypeChecker.typeNamedLiterally(
  'GenUiProp',
  inPackage: 'genui_gen',
);

/// Matches `@GenUiAction` from `package:genui_gen`.
const genUiActionChecker = TypeChecker.typeNamedLiterally(
  'GenUiAction',
  inPackage: 'genui_gen',
);

/// The extension the builder appends to the annotated file name.
const generatedPartExtension = '.genui.dart';

/// Component names genui's own basic catalog already uses.
///
/// From `BasicCatalogItems` in genui 0.10; `Text` is handled separately
/// because generated examples compose it for child components.
const _basicCatalogNames = {
  'AudioPlayer',
  'Button',
  'Card',
  'CheckBox',
  'ChoicePicker',
  'Column',
  'DateTimeInput',
  'Divider',
  'Icon',
  'Image',
  'List',
  'Modal',
  'Row',
  'Slider',
  'Tabs',
  'TextField',
  'Video',
};

/// Generates a `CatalogItem` for every class annotated with `@GenUiWidget`.
///
/// The annotation type is matched by name and package (see
/// [genUiWidgetChecker]) rather than through a Dart import of
/// `package:genui_gen`, because that package depends on Flutter and cannot be
/// loaded into the `build_runner` VM isolate.
class GenUiGenerator extends GeneratorForAnnotation<Object> {
  const GenUiGenerator();

  @override
  TypeChecker get typeChecker => genUiWidgetChecker;

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    _checkVariableNameClashes(
      library,
      genUiWidgetChecker,
      (name) => '${lowerCamel(name)}CatalogItem',
    );
    return super.generate(library, buildStep);
  }

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@GenUiWidget can only be applied to classes, but '
        '`${element.displayName}` is a ${element.kind.displayName}.',
        element: element,
      );
    }
    final spec = buildWidgetSpec(element, annotation);
    final code = emitCatalogItem(spec);
    checkImports(element.library, code.symbols, element);
    return code.source;
  }
}

/// Generates the schema and the decoder for every class annotated with
/// `@GenUiData`.
///
/// Both declarations land in the same `.genui.dart` part as the catalog items
/// of the library, so a file may mix annotated widgets and annotated data
/// classes.
class GenUiDataGenerator extends GeneratorForAnnotation<Object> {
  const GenUiDataGenerator();

  @override
  TypeChecker get typeChecker => genUiDataChecker;

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    _checkVariableNameClashes(
      library,
      genUiDataChecker,
      (name) => '${lowerCamel(name)}GenUiSchema',
    );
    return super.generate(library, buildStep);
  }

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@GenUiData can only be applied to classes, but '
        '`${element.displayName}` is a ${element.kind.displayName}.',
        element: element,
      );
    }
    if (genUiWidgetChecker.hasAnnotationOf(element)) {
      throw InvalidGenerationSourceError(
        '`${element.displayName}` is annotated with both @GenUiWidget and '
        '@GenUiData. A widget is a component the model references, a data '
        'class is a value the model emits; keep them apart.',
        element: element,
      );
    }
    final spec = buildDataSpec(element, annotation, const []);
    final code = emitDataClass(spec);
    checkImports(element.library, code.symbols, element);
    return code.source;
  }
}

/// Rejects libraries where two annotated classes would share a generated
/// variable name (`HTTPCard` and `HttpCard` both lower-camel to `httpCard`).
void _checkVariableNameClashes(
  LibraryReader library,
  TypeChecker checker,
  String Function(String className) variableName,
) {
  final byVariable = <String, Element>{};
  for (final annotated in library.annotatedWith(checker)) {
    final element = annotated.element;
    final name = element.name;
    if (element is! ClassElement || name == null) continue;
    final variable = variableName(name);
    final previous = byVariable[variable];
    if (previous != null) {
      throw InvalidGenerationSourceError(
        'Classes `${previous.displayName}` and `$name` would both generate '
        '`$variable`. Rename one of them so their lower-camel names differ.',
        element: element,
      );
    }
    byVariable[variable] = element;
  }
}

/// Analyses an annotated class into a [WidgetSpec].
///
/// Throws [InvalidGenerationSourceError] for anything the generator cannot
/// handle; every message names the widget and, where relevant, the parameter.
WidgetSpec buildWidgetSpec(ClassElement cls, ConstantReader annotation) {
  final className = cls.name;
  if (className == null) {
    throw InvalidGenerationSourceError(
      '@GenUiWidget requires a named class.',
      element: cls,
    );
  }

  if (!widgetChecker.isAssignableFrom(cls)) {
    throw InvalidGenerationSourceError(
      '@GenUiWidget on `$className` requires a class that extends Widget, '
      'but `$className` does not.',
      element: cls,
    );
  }
  if (cls.isAbstract) {
    throw InvalidGenerationSourceError(
      '@GenUiWidget cannot be applied to abstract class `$className`; the '
      'generated builder must instantiate it.',
      element: cls,
    );
  }

  final description = _readString(annotation, 'description');
  if (description == null || description.trim().isEmpty) {
    throw InvalidGenerationSourceError(
      '@GenUiWidget on `$className` needs a non-empty `description`; it is '
      'what the model reads to decide when to use the component.',
      element: cls,
    );
  }

  final catalogName = _readString(annotation, 'name') ?? className;
  if (catalogName == 'Text') {
    throw InvalidGenerationSourceError(
      'Component name `Text` on `$className` collides with the core catalog '
      'item that the generated examples use for child components. Pick '
      'another name with @GenUiWidget(name: ...).',
      element: cls,
    );
  }
  if (_basicCatalogNames.contains(catalogName)) {
    // Not an error: a catalog is free to leave the basic items out, and then
    // the name is available. It is worth saying out loud, though, because
    // `Catalog.copyWith(newItems: ...)` next to `BasicCatalogItems` gives the
    // model two components with one name and no indication which it composed.
    log.warning(
      'Component name `$catalogName` on `$className` is also a genui basic '
      'catalog item. Registering both in one catalog leaves the model with '
      'two components under that name. Rename it with '
      '@GenUiWidget(name: ...) if the catalog includes '
      'BasicCatalogItems.asCatalog().',
    );
  }
  if (catalogName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      '`$className` is private; the model would see `$catalogName` as the '
      'component name. Give it a public name with @GenUiWidget(name: ...).',
      element: cls,
    );
  }

  final constructorName = _readString(annotation, 'constructor');
  final constructor = _selectConstructor(
    cls,
    className,
    constructorName,
    '@GenUiWidget',
  );

  final props = _analyseParameters(
    cls,
    className,
    constructor,
    inData: false,
    stack: const [],
  );

  checkGeneratedNameClashes(className, [
    for (final prop in props)
      if (prop.data != null) prop.data!,
  ], cls);

  return WidgetSpec(
    className: className,
    constructorName: constructorName ?? '',
    catalogName: catalogName,
    description: description.trim(),
    isImplicitlyFlexible: _readBool(annotation, 'isImplicitlyFlexible'),
    props: props,
  );
}

/// Analyses a `@GenUiData` class into a [DataSpec].
///
/// [stack] holds the data classes currently being analysed, innermost last, so
/// that a class reaching itself is reported as a cycle instead of recursing
/// forever.
DataSpec buildDataSpec(
  ClassElement cls,
  ConstantReader annotation,
  List<ClassElement> stack,
) {
  final className = cls.name;
  if (className == null) {
    throw InvalidGenerationSourceError(
      '@GenUiData requires a named class.',
      element: cls,
    );
  }

  final cycleStart = stack.indexOf(cls);
  if (cycleStart >= 0) {
    final path = [
      ...stack.skip(cycleStart).map((e) => e.displayName),
      className,
    ].join(' -> ');
    throw InvalidGenerationSourceError(
      'Data class cycle: $path. A `@GenUiData` schema is inlined into the '
      'schema that uses it, and an inlined schema cannot describe itself. '
      'Break the cycle, or mark the field @GenUiProp(ignore: true).',
      element: cls,
    );
  }

  if (cls.isAbstract) {
    throw InvalidGenerationSourceError(
      '@GenUiData cannot be applied to abstract class `$className`; the '
      'generated decoder must instantiate it.',
      element: cls,
    );
  }
  if (cls.typeParameters.isNotEmpty) {
    final parameters = cls.typeParameters.map((p) => p.name ?? '?').join(', ');
    throw InvalidGenerationSourceError(
      '@GenUiData cannot be applied to generic class `$className<$parameters>`. '
      'The schema is inlined JSON Schema, which cannot express a type '
      'parameter, and the generated decoder can only name the bare '
      '`$className`. Declare a concrete class per shape the model may emit.',
      element: cls,
    );
  }

  final constructorName = _readString(annotation, 'constructor');
  final constructor = _selectConstructor(
    cls,
    className,
    constructorName,
    '@GenUiData',
  );

  final description =
      _readString(annotation, 'description')?.trim() ??
      cleanDocComment(cls.documentationComment);

  final fields = _analyseParameters(
    cls,
    className,
    constructor,
    inData: true,
    stack: [...stack, cls],
  );

  for (final field in fields) {
    if (field.schemaName != 'path' && field.schemaName != 'call') continue;
    throw InvalidGenerationSourceError(
      'Field `$className.${field.dartName}` would use the wire key '
      '`${field.schemaName}`, which genui reserves. A property value whose '
      'map has a String `path` is resolved as a data binding, and one that '
      'contains `call` as a function call, so an object carrying that key is '
      'never delivered to the widget as a literal. Rename the wire key with '
      "@GenUiProp(name: '<other>'), or leave the field out with "
      '@GenUiProp(ignore: true).',
      element: cls,
    );
  }

  checkGeneratedNameClashes(className, [
    for (final field in fields)
      if (field.data != null) field.data!,
  ], cls);

  return DataSpec(
    className: className,
    constructorName: constructorName ?? '',
    description: (description == null || description.isEmpty)
        ? null
        : description,
    fields: fields,
    libraryUri: cls.library.uri.toString(),
  );
}

/// Rejects two distinct data classes whose generated names would collide at
/// the use site.
///
/// [_checkVariableNameClashes] catches a collision inside one library, but the
/// generated part of [owner] references the schema and decoder of every data
/// class it uses as plain identifiers. Two classes declared in *different*
/// libraries whose lower-camel names coincide (`HTTPRow` and `HttpRow`) both
/// generate `httpRowGenUiSchema`, and the use site would see an ambiguous
/// import instead of a build error.
void checkGeneratedNameClashes(
  String owner,
  List<DataSpec> referenced,
  Element element,
) {
  final byName = <String, DataSpec>{};
  for (final spec in referenced) {
    final previous = byName[spec.schemaVariableName];
    if (previous == null) {
      byName[spec.schemaVariableName] = spec;
      continue;
    }
    if (previous.className == spec.className &&
        previous.libraryUri == spec.libraryUri) {
      continue;
    }
    throw InvalidGenerationSourceError(
      'Data classes `${previous.className}` (${previous.libraryUri}) and '
      '`${spec.className}` (${spec.libraryUri}) are both used by `$owner` and '
      'would both generate `${spec.schemaVariableName}` and '
      '`${spec.decoderName}`. The generated code names them unprefixed, so '
      'the two would clash. Rename one of the classes so their lower-camel '
      'names differ.',
      element: element,
    );
  }
}

/// The constructor named by the annotation, or the unnamed one.
ConstructorElement _selectConstructor(
  ClassElement cls,
  String className,
  String? constructorName,
  String annotationName,
) {
  final constructor = constructorName == null
      ? cls.unnamedConstructor
      : cls.getNamedConstructor(constructorName);
  if (constructor == null) {
    final wanted = constructorName == null
        ? 'an unnamed constructor'
        : 'a constructor named `$constructorName`';
    throw InvalidGenerationSourceError(
      '$annotationName on `$className` expects $wanted, but none was found. '
      'Pass `constructor: \'<name>\'` to pick a named constructor.',
      element: cls,
    );
  }
  return constructor;
}

/// Analyses every parameter of [constructor] into a [PropSpec], skipping the
/// ones that are left out of the schema.
List<PropSpec> _analyseParameters(
  ClassElement cls,
  String className,
  ConstructorElement constructor, {
  required bool inData,
  required List<ClassElement> stack,
}) {
  final props = <PropSpec>[];
  FormalParameterElement? skippedPositional;
  for (final param in constructor.formalParameters) {
    final prop = _analyseParameter(
      cls,
      className,
      param,
      inData: inData,
      stack: stack,
    );
    if (prop == null) {
      if (!param.isNamed) skippedPositional ??= param;
      continue;
    }
    if (!param.isNamed && skippedPositional != null) {
      throw InvalidGenerationSourceError(
        '`$className.${skippedPositional.name}` is positional and cannot be '
        'left out of the schema because the later positional parameter '
        '`${param.name}` would shift into its slot. Make it a named '
        'parameter, or ignore the positional parameters after it too.',
        element: skippedPositional,
      );
    }
    final clash = props.where((p) => p.schemaName == prop.schemaName);
    if (clash.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Property name `${prop.schemaName}` is used by both '
        '`$className.${clash.first.dartName}` and `$className.${prop.dartName}`. '
        'Schema property names must be unique; use @GenUiProp(name: ...) to '
        'rename one of them.',
        element: param,
      );
    }
    props.add(prop);
  }
  return props;
}

PropSpec? _analyseParameter(
  ClassElement cls,
  String className,
  FormalParameterElement param, {
  required bool inData,
  required List<ClassElement> stack,
}) {
  final name = param.name;
  if (name == null || name.isEmpty) {
    throw InvalidGenerationSourceError(
      'Constructor of `$className` has an unnamed parameter; every '
      'parameter must have a name to become a property.',
      element: param,
    );
  }
  final qualified = '$className.$name';

  // `key` is part of every widget constructor and never part of the schema.
  // Inside a data class it is an ordinary field that happens to be called
  // `key`, so it must not be dropped.
  if (!inData && _isKeyParameter(param)) return null;

  // Annotations may sit on the parameter or, for `this.x` formals, on the
  // backing field next to its doc comment.
  final field = param is FieldFormalParameterElement
      ? cls.getField(name)
      : null;
  final propAnnotation =
      _annotation(genUiPropChecker, param) ??
      (field == null ? null : _annotation(genUiPropChecker, field));
  final actionAnnotation =
      _annotation(genUiActionChecker, param) ??
      (field == null ? null : _annotation(genUiActionChecker, field));

  if (propAnnotation != null && _readBool(propAnnotation, 'ignore')) {
    if (param.isRequired) {
      throw InvalidGenerationSourceError(
        '`$qualified` is marked @GenUiProp(ignore: true) but it is a '
        'required parameter, so the generated ${inData ? 'decoder' : 'builder'} '
        'could not construct the ${inData ? 'value' : 'widget'} without it. '
        'Make it optional or give it a default value.',
        element: param,
      );
    }
    return null;
  }

  if (hasUnresolvedType(param.type)) {
    throw InvalidGenerationSourceError(
      'The type of `$qualified` could not be resolved, so the generator '
      'cannot map it. This is almost always a missing import in '
      '${cls.library.uri}, a typo in the type name, or a name two imports '
      'both provide (hide one of them or import it with a prefix). Fix the '
      'type first; the generator reports unsupported types separately.',
      element: param,
    );
  }

  final mapping = mapType(param.type);
  if (mapping == null) {
    final nullableElement = nullableListElement(param.type);
    if (nullableElement != null) {
      throw InvalidGenerationSourceError(
        '`$qualified` has type `${param.type.getDisplayString()}`, whose '
        'elements are nullable. A list element may not be nullable: the '
        'schema cannot say that one entry is null, and the generated code '
        'would have nothing to build for it. Use '
        '`List<${nullableElement.substring(0, nullableElement.length - 1)}>`, '
        'or make the property itself nullable.',
        element: param,
      );
    }
    final annotatable = annotatableClassName(param.type);
    final hint = annotatable == null
        ? ''
        : ' If `$annotatable` is a plain data class of your own, add '
              '@GenUiData to $annotatable so the model can emit it as an '
              'object.';
    throw InvalidGenerationSourceError(
      'Unsupported parameter type `${param.type.getDisplayString()}` for '
      '`$qualified`. Supported types: '
      '${inData ? supportedDataTypesSummary : supportedTypesSummary}.$hint '
      'Annotate the parameter with @GenUiProp(ignore: true) to leave it out '
      'of the schema (it must then be optional or have a default value).',
      element: param,
    );
  }

  if (inData && !_allowedInDataClass(mapping.kind)) {
    throw InvalidGenerationSourceError(
      '`$qualified` has type `${param.type.getDisplayString()}`, which is not '
      'allowed inside a @GenUiData class: a data class is data the model '
      'emits, not a component reference or a callback. Move it to the '
      'widget constructor, or mark it @GenUiProp(ignore: true).',
      element: param,
    );
  }

  if (actionAnnotation != null && mapping.kind != PropKind.action) {
    throw InvalidGenerationSourceError(
      '@GenUiAction on `$qualified` requires a `VoidCallback` / '
      '`void Function()` parameter, but its type is '
      '`${param.type.getDisplayString()}`.',
      element: param,
    );
  }

  final schemaName = _readString(propAnnotation, 'name') ?? name;
  if (!_validPropertyName.hasMatch(schemaName)) {
    throw InvalidGenerationSourceError(
      'Invalid property name `$schemaName` for `$qualified`. Names must '
      'match ${_validPropertyName.pattern}.',
      element: param,
    );
  }

  final description =
      _readString(actionAnnotation, 'description') ??
      _readString(propAnnotation, 'description') ??
      cleanDocComment(param.documentationComment) ??
      cleanDocComment(_fieldDocComment(cls, name));

  String? enumTypeName;
  var enumValues = const <String>[];
  if (mapping.kind == PropKind.enumeration) {
    final enumElement = mapping.enumElement!;
    enumTypeName = _visibleTypeName(
      cls.library,
      enumElement,
      'Enum',
      param,
      qualified,
      'reference `${enumElement.name}.values`',
    );
    enumValues = [for (final c in enumElement.constants) c.name!];
  }

  DataSpec? data;
  if (mapping.kind.isData) {
    data = _analyseDataReference(
      cls,
      mapping.dataElement!,
      param,
      qualified,
      stack,
    );
  }

  return PropSpec(
    dartName: name,
    schemaName: schemaName,
    kind: mapping.kind,
    isNullable: mapping.isNullable,
    isRequiredInConstructor: param.isRequired,
    isNamed: param.isNamed,
    defaultValueCode: _defaultValueCode(cls, param, qualified),
    description: description,
    enumTypeName: enumTypeName,
    enumValues: enumValues,
    eventName: _readString(actionAnnotation, 'eventName') ?? name,
    data: data,
  );
}

/// Only these kinds may appear inside a `@GenUiData` class.
bool _allowedInDataClass(PropKind kind) => switch (kind) {
  PropKind.string ||
  PropKind.integer ||
  PropKind.decimal ||
  PropKind.number ||
  PropKind.boolean ||
  PropKind.enumeration ||
  PropKind.stringList ||
  PropKind.data ||
  PropKind.dataList => true,
  PropKind.widget || PropKind.widgetList || PropKind.action => false,
};

/// Analyses the data class [dataElement] referenced from [cls], after
/// checking that the generated code of [cls]'s library can actually name its
/// schema and decoder.
///
/// The generated part is a `part of` the library that declares [cls], so it
/// reaches the two generated top-level declarations of the data class only
/// when
///
/// 1. the data class itself is visible there without an import prefix, and
/// 2. the library declaring the data class has the `part '<file>.genui.dart';`
///    directive that holds them.
///
/// Both conditions hold automatically when the data class lives in the same
/// file; across files they are checked here so the failure is a build error
/// with a fix, not an unresolved identifier in generated code.
DataSpec _analyseDataReference(
  ClassElement cls,
  ClassElement dataElement,
  FormalParameterElement param,
  String qualified,
  List<ClassElement> stack,
) {
  _visibleTypeName(
    cls.library,
    dataElement,
    'Data class',
    param,
    qualified,
    'name its generated schema and decoder',
  );
  _checkGeneratedPart(dataElement, param, qualified);
  _checkImportCombinators(cls, dataElement, param, qualified);
  final annotation = _annotation(genUiDataChecker, dataElement)!;
  return buildDataSpec(dataElement, annotation, stack);
}

/// Verifies that at least one unprefixed import of the data class's library
/// lets both generated names through its `show` / `hide` combinators.
///
/// `import 'models.dart' show MetricRow;` makes the class itself visible — so
/// [_visibleTypeName] is happy — while filtering out `metricRowGenUiSchema`
/// and `metricRowFromGenUiJson`, which the generated part must name. Without
/// this check the build succeeds and the generated file does not compile.
///
/// Only direct imports of the declaring library are inspected. When the class
/// arrives through a re-exporting barrel there is no combinator here to reason
/// about, and the check stays out of the way.
void _checkImportCombinators(
  ClassElement cls,
  ClassElement dataElement,
  FormalParameterElement param,
  String qualified,
) {
  final target = dataElement.library;
  if (identical(target, cls.library)) return;

  final name = dataElement.name!;
  final schemaName = '${lowerCamel(name)}GenUiSchema';
  final decoderName = '${lowerCamel(name)}FromGenUiJson';

  final blocked = <String>[];
  for (final fragment in cls.library.fragments) {
    for (final import in fragment.libraryImports) {
      if (import.prefix != null) continue;
      if (!identical(import.importedLibrary, target)) continue;
      final reason = _combinatorBlocking(import, [schemaName, decoderName]);
      if (reason == null) return;
      blocked.add(reason);
    }
  }
  if (blocked.isEmpty) return;

  throw InvalidGenerationSourceError(
    'Data class `$name` used by `$qualified` is imported from ${target.uri} '
    'with a combinator that hides its generated declarations: '
    '${blocked.join('; ')}. The generated code names `$schemaName` and '
    '`$decoderName` directly, so both must be visible. Add them to the '
    '`show` list (or drop them from the `hide` list), or add a second '
    'unprefixed import of ${target.uri} without a combinator.',
    element: param,
  );
}

/// Why [import] does not let all of [names] through, or `null` when it does.
String? _combinatorBlocking(LibraryImport import, List<String> names) {
  for (final combinator in import.combinators) {
    if (combinator is ShowElementCombinator) {
      final shown = combinator.shownNames.toSet();
      final missing = names.where((n) => !shown.contains(n)).toList();
      if (missing.isNotEmpty) {
        return '`show ${combinator.shownNames.join(', ')}` leaves out '
            '${missing.join(' and ')}';
      }
    } else if (combinator is HideElementCombinator) {
      final hidden = combinator.hiddenNames.toSet();
      final blocked = names.where(hidden.contains).toList();
      if (blocked.isNotEmpty) {
        return '`hide ${combinator.hiddenNames.join(', ')}` removes '
            '${blocked.join(' and ')}';
      }
    }
  }
  return null;
}

/// Verifies that the library declaring [dataElement] includes the generated
/// part that will hold its schema and decoder.
void _checkGeneratedPart(
  ClassElement dataElement,
  FormalParameterElement param,
  String qualified,
) {
  final library = dataElement.library;
  final uri = library.uri;
  final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  if (!path.endsWith('.dart')) return;
  final expected =
      '${path.substring(0, path.length - '.dart'.length)}'
      '$generatedPartExtension';
  for (final fragment in library.fragments) {
    for (final include in fragment.partIncludes) {
      final includeUri = include.uri;
      if (includeUri is! DirectiveUriWithRelativeUriString) continue;
      if (includeUri.relativeUriString == expected) return;
    }
  }
  throw InvalidGenerationSourceError(
    'Data class `${dataElement.displayName}` used by `$qualified` is declared '
    'in $uri, which has no `part \'$expected\';` directive, so its generated '
    'schema and decoder are never written. Add that part directive to '
    '$uri.',
    element: param,
  );
}

final _validPropertyName = RegExp(r'^[A-Za-z_][A-Za-z0-9_\-]*$');

/// The default value source to emit for [param].
///
/// A `super.x` formal inherits the default of the superclass constructor, and
/// the analyzer reports that superclass's source verbatim. When the
/// superclass lives in another library, identifiers in that source (private
/// constants, unimported names) do not resolve in the generated part, so only
/// self-contained literals are accepted from there.
String? _defaultValueCode(
  ClassElement cls,
  FormalParameterElement param,
  String qualified,
) {
  final code = param.defaultValueCode;
  if (code == null || param is! SuperFormalParameterElement) return code;
  final inherited = param.superConstructorParameter;
  if (inherited == null || inherited.library == cls.library) return code;
  if (_literalDefault.hasMatch(code)) return code;
  throw InvalidGenerationSourceError(
    '`$qualified` inherits the default value `$code` from '
    '`${inherited.enclosingElement?.displayName}` in '
    '${inherited.library?.uri}, which may not resolve in the generated code. '
    'Redeclare it as `this.${param.name} = <default>` or mark it '
    '@GenUiProp(ignore: true).',
    element: param,
  );
}

/// Numbers, strings without interpolation, `true`, `false` and `null`.
final _literalDefault = RegExp(
  r'''^(-?\d+(\.\d+)?|true|false|null|'[^'$\\]*'|"[^"$\\]*")$''',
);

/// `Key? key` and `super.key` are part of every widget and never part of the
/// schema.
bool _isKeyParameter(FormalParameterElement param) {
  if (param.name != 'key') return false;
  if (param is SuperFormalParameterElement) return true;
  final type = param.type;
  if (type is DynamicType) return true;
  return type.element?.name?.endsWith('Key') ?? false;
}

/// The name under which [target] is visible from [library], so the generated
/// part can reference it unprefixed.
String _visibleTypeName(
  LibraryElement library,
  Element target,
  String label,
  FormalParameterElement param,
  String qualified,
  String need,
) {
  final name = target.name!;
  final resolved = library.firstFragment.scope.lookup(name).getter;
  if (resolved == target) return name;
  throw InvalidGenerationSourceError(
    '$label `$name` used by `$qualified` is not visible unprefixed in '
    '${library.uri}. Import it without a prefix so the generated code can '
    '$need.',
    element: param,
  );
}

/// Doc comment of the field backing an initializing or super formal.
String? _fieldDocComment(ClassElement cls, String name) {
  final own = cls.getField(name)?.documentationComment;
  if (own != null) return own;
  for (final supertype in cls.allSupertypes) {
    final doc = supertype.element.getField(name)?.documentationComment;
    if (doc != null) return doc;
  }
  return null;
}

ConstantReader? _annotation(TypeChecker checker, Element element) {
  final value = checker.firstAnnotationOf(element);
  return value == null ? null : ConstantReader(value);
}

String? _readString(ConstantReader? reader, String field) {
  final value = reader?.peek(field);
  if (value == null || value.isNull) return null;
  return value.stringValue;
}

bool _readBool(ConstantReader? reader, String field) {
  final value = reader?.peek(field);
  if (value == null || value.isNull) return false;
  return value.boolValue;
}
