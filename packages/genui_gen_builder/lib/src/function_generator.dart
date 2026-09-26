import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'emitter.dart';
import 'imports.dart';
import 'spec.dart';
import 'strings.dart';
import 'type_mapping.dart';

/// Matches `@GenUiFunction` from `package:genui_gen`.
const genUiFunctionChecker = TypeChecker.typeNamedLiterally(
  'GenUiFunction',
  inPackage: 'genui_gen',
);

/// Matches `@GenUiProp`, which may also describe or rename an argument.
const _propChecker = TypeChecker.typeNamedLiterally(
  'GenUiProp',
  inPackage: 'genui_gen',
);

/// Function names genui's own basic catalog already registers.
///
/// A catalog is a map from name to function, so a second `required` would
/// replace the one the basic catalog put there and change what every existing
/// prompt means.
///
/// Taken from `basic_functions.dart` and `format_string.dart` in genui 0.10,
/// and the same fourteen the published basic catalog declares.
const _basicCatalogFunctions = {
  'and',
  'email',
  'formatCurrency',
  'formatDate',
  'formatNumber',
  'formatString',
  'length',
  'not',
  'numeric',
  'openUrl',
  'or',
  'pluralize',
  'regex',
  'required',
};


final _validName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Generates a `ClientFunction` for every top-level function annotated with
/// `@GenUiFunction`.
///
/// Like the widget generator, the annotation is matched by name and package
/// rather than through a Dart import of `package:genui_gen`, which depends on
/// Flutter and cannot be loaded into the `build_runner` isolate.
class GenUiFunctionGenerator extends GeneratorForAnnotation<Object> {
  const GenUiFunctionGenerator();

  @override
  TypeChecker get typeChecker => genUiFunctionChecker;

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@GenUiFunction can only be applied to top-level functions, but '
        '`${element.displayName}` is a ${element.kind.displayName}. A method '
        'or a static member has a receiver the catalog has no way to name.',
        element: element,
      );
    }
    final spec = buildFunctionSpec(element, annotation);
    final code = emitFunction(spec);
    checkImports(element.library, code.symbols, element);
    return code.source;
  }
}

/// Analyses [function] into the [FunctionSpec] the emitter turns into source.
FunctionSpec buildFunctionSpec(
  TopLevelFunctionElement function,
  ConstantReader annotation,
) {
  final dartName = function.name;
  if (dartName == null || dartName.isEmpty) {
    throw InvalidGenerationSourceError(
      'A @GenUiFunction must have a name.',
      element: function,
    );
  }
  if (dartName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      '`$dartName` is private, so the generated variable would be private too '
      'and no other library could put it in a catalog. Make the function '
      'public.',
      element: function,
    );
  }

  final description = annotation.read('description').stringValue;
  if (description.trim().isEmpty) {
    throw InvalidGenerationSourceError(
      '@GenUiFunction on `$dartName` has an empty description. It is what the '
      'model reads to decide when to call the function, so a catalog entry '
      'without one is useless to it.',
      element: function,
    );
  }

  final Object? configuredName = annotation.read('name').isNull
      ? null
      : annotation.read('name').stringValue;
  final functionName = (configuredName as String?) ?? dartName;
  if (!_validName.hasMatch(functionName)) {
    throw InvalidGenerationSourceError(
      'Invalid function name `$functionName` for `$dartName`. Names must '
      'match ${_validName.pattern}.',
      element: function,
    );
  }
  if (_basicCatalogFunctions.contains(functionName)) {
    throw InvalidGenerationSourceError(
      '`$functionName` is the name of a function in genui\'s basic catalog. '
      'Two functions cannot share a name in one catalog, and replacing that '
      'one changes what every prompt written against it means. Rename it '
      'with @GenUiFunction(name: ...).',
      element: function,
    );
  }

  final (returns, delivery) = _analyseReturn(function, dartName);

  final args = <PropSpec>[];
  for (final param in function.formalParameters) {
    args.add(_analyseArgument(function, dartName, param));
  }

  return FunctionSpec(
    dartName: dartName,
    functionName: functionName,
    description: description,
    args: args,
    returns: returns,
    delivery: delivery,
  );
}

(FunctionReturn, FunctionDelivery) _analyseReturn(
  TopLevelFunctionElement function,
  String dartName,
) {
  var type = function.returnType;
  var delivery = FunctionDelivery.sync;

  if (type.isDartAsyncFuture || type.isDartAsyncStream) {
    delivery = type.isDartAsyncStream
        ? FunctionDelivery.streaming
        : FunctionDelivery.async;
    final args = type is InterfaceType
        ? type.typeArguments
        : const <DartType>[];
    if (args.length != 1) {
      throw InvalidGenerationSourceError(
        '`$dartName` returns `${type.getDisplayString()}`, whose value type '
        'the generator cannot read. Give it one type argument, such as '
        '`Future<String>`.',
        element: function,
      );
    }
    type = args.single;
  }

  return (_returnKind(type, function, dartName), delivery);
}

FunctionReturn _returnKind(
  DartType type,
  TopLevelFunctionElement function,
  String dartName,
) {
  if (type is VoidType) return FunctionReturn.empty;
  if (type is DynamicType) return FunctionReturn.any;
  if (type.isDartCoreObject) return FunctionReturn.any;
  if (type.isDartCoreString) return FunctionReturn.string;
  if (type.isDartCoreBool) return FunctionReturn.boolean;
  if (type.isDartCoreNum || type.isDartCoreInt || type.isDartCoreDouble) {
    return FunctionReturn.number;
  }
  if (type.isDartCoreList) return FunctionReturn.array;
  if (type.isDartCoreMap) return FunctionReturn.object;
  if (dataClassOf(type) != null) return FunctionReturn.object;

  final mapping = mapType(type);
  if (mapping?.kind == PropKind.enumeration) return FunctionReturn.string;

  throw InvalidGenerationSourceError(
    '`$dartName` returns `${type.getDisplayString()}`, which the generator '
    'cannot describe to the model. A catalog function returns a value the '
    'expression system can put in a property: a String, a number, a bool, an '
    'enum, a List, a Map, a @GenUiData class, or void.',
    element: function,
  );
}

PropSpec _analyseArgument(
  TopLevelFunctionElement function,
  String dartName,
  FormalParameterElement param,
) {
  final name = param.name;
  if (name == null || name.isEmpty) {
    throw InvalidGenerationSourceError(
      '`$dartName` has an unnamed parameter; every parameter must have a name '
      'to become an argument.',
      element: param,
    );
  }
  final qualified = '$dartName.$name';

  if (hasUnresolvedType(param.type)) {
    throw InvalidGenerationSourceError(
      'The type of `$qualified` could not be resolved. This is almost always '
      'a missing import in ${function.library.uri} or a typo in the type name.',
      element: param,
    );
  }

  final mapping = mapType(param.type);
  if (mapping == null || !_isArgumentKind(mapping.kind)) {
    throw InvalidGenerationSourceError(
      '`$qualified` has type `${param.type.getDisplayString()}`, which a '
      'catalog function cannot take. An argument is a value the model sends '
      'or binds to a path: a String, a number, a bool, an enum, a List of '
      'those, or a @GenUiData class. A Widget or a callback is a component '
      'reference, which a function has nothing to build.',
      element: param,
    );
  }

  final propAnnotation = _propChecker.firstAnnotationOf(param);
  final reader = propAnnotation == null ? null : ConstantReader(propAnnotation);
  final renamed = reader == null || reader.read('name').isNull
      ? null
      : reader.read('name').stringValue;
  final described = reader == null || reader.read('description').isNull
      ? null
      : reader.read('description').stringValue;

  final schemaName = renamed ?? name;
  if (!_validName.hasMatch(schemaName)) {
    throw InvalidGenerationSourceError(
      'Invalid argument name `$schemaName` for `$qualified`.',
      element: param,
    );
  }

  return PropSpec(
    dartName: name,
    schemaName: schemaName,
    kind: mapping.kind,
    isNullable: mapping.isNullable,
    isRequiredInConstructor: param.isRequired,
    isNamed: param.isNamed,
    defaultValueCode: param.defaultValueCode,
    description: described ?? cleanDocComment(param.documentationComment),
    enumTypeName: mapping.enumElement?.name,
    enumValues: [
      if (mapping.enumElement != null)
        for (final c in mapping.enumElement!.constants) c.name!,
    ],
    data: null,
  );
}

/// Whether [kind] is something a function argument may be.
///
/// Components and actions are left out on purpose: a function receives values
/// the expression system resolved, and has no surface to build a child on or
/// to dispatch an event from.
bool _isArgumentKind(PropKind kind) => switch (kind) {
  PropKind.string ||
  PropKind.integer ||
  PropKind.decimal ||
  PropKind.number ||
  PropKind.boolean ||
  PropKind.enumeration ||
  PropKind.stringList ||
  PropKind.integerList ||
  PropKind.decimalList ||
  PropKind.numberList ||
  PropKind.enumerationList => true,
  PropKind.data ||
  PropKind.dataList ||
  PropKind.widget ||
  PropKind.widgetList ||
  PropKind.action ||
  PropKind.valueWriter => false,
};
