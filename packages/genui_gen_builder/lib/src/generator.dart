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
    _checkVariableNameClashes(library);
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

/// Rejects libraries where two annotated classes would share a generated
/// variable name (`HTTPCard` and `HttpCard` both lower-camel to `httpCard`).
void _checkVariableNameClashes(LibraryReader library) {
  final byVariable = <String, Element>{};
  for (final annotated in library.annotatedWith(genUiWidgetChecker)) {
    final element = annotated.element;
    final name = element.name;
    if (element is! ClassElement || name == null) continue;
    final variable = '${lowerCamel(name)}CatalogItem';
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
  if (catalogName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      '`$className` is private; the model would see `$catalogName` as the '
      'component name. Give it a public name with @GenUiWidget(name: ...).',
      element: cls,
    );
  }

  final constructorName = _readString(annotation, 'constructor');
  final constructor = constructorName == null
      ? cls.unnamedConstructor
      : cls.getNamedConstructor(constructorName);
  if (constructor == null) {
    final wanted = constructorName == null
        ? 'an unnamed constructor'
        : 'a constructor named `$constructorName`';
    throw InvalidGenerationSourceError(
      '@GenUiWidget on `$className` expects $wanted, but none was found. '
      'Pass `constructor: \'<name>\'` to pick a named constructor.',
      element: cls,
    );
  }

  final props = <PropSpec>[];
  FormalParameterElement? skippedPositional;
  for (final param in constructor.formalParameters) {
    final prop = _analyseParameter(cls, className, param);
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

  return WidgetSpec(
    className: className,
    constructorName: constructorName ?? '',
    catalogName: catalogName,
    description: description.trim(),
    isImplicitlyFlexible: _readBool(annotation, 'isImplicitlyFlexible'),
    props: props,
  );
}

PropSpec? _analyseParameter(
  ClassElement cls,
  String className,
  FormalParameterElement param,
) {
  final name = param.name;
  if (name == null || name.isEmpty) {
    throw InvalidGenerationSourceError(
      'Constructor of `$className` has an unnamed parameter; every '
      'parameter must have a name to become a property.',
      element: param,
    );
  }
  final qualified = '$className.$name';

  if (_isKeyParameter(param)) return null;

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
        'required parameter, so the generated builder could not construct '
        'the widget without it. Make it optional or give it a default value.',
        element: param,
      );
    }
    return null;
  }

  final mapping = mapType(param.type);
  if (mapping == null) {
    throw InvalidGenerationSourceError(
      'Unsupported parameter type `${param.type.getDisplayString()}` for '
      '`$qualified`. Supported types: $supportedTypesSummary. Annotate the '
      'parameter with @GenUiProp(ignore: true) to leave it out of the schema '
      '(it must then be optional or have a default value).',
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
    enumTypeName = _visibleEnumName(cls.library, enumElement, param, qualified);
    enumValues = [for (final c in enumElement.constants) c.name!];
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

/// The name under which [enumElement] is visible from [library], so the
/// generated part can write `<Enum>.values`.
String _visibleEnumName(
  LibraryElement library,
  EnumElement enumElement,
  FormalParameterElement param,
  String qualified,
) {
  final name = enumElement.name!;
  final resolved = library.firstFragment.scope.lookup(name).getter;
  if (resolved == enumElement) return name;
  throw InvalidGenerationSourceError(
    'Enum `$name` used by `$qualified` is not visible unprefixed in '
    '${library.uri}. Import it without a prefix so the generated code can '
    'reference `$name.values`.',
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
