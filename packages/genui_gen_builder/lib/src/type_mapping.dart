/// Maps Dart parameter types to [PropKind]s.
///
/// This is the single place that decides which types are supported (see the
/// "Type mapping" table in the repository's DESIGN.md).
library;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'spec.dart';

/// Matches Flutter's `Widget` class.
const widgetChecker = TypeChecker.typeNamedLiterally(
  'Widget',
  inPackage: 'flutter',
);

/// Matches `@GenUiData` from `package:genui_gen`.
const genUiDataChecker = TypeChecker.typeNamedLiterally(
  'GenUiData',
  inPackage: 'genui_gen',
);

/// Result of mapping a type: either a supported [kind] or `null`.
final class TypeMapping {
  const TypeMapping({
    required this.kind,
    required this.isNullable,
    this.enumElement,
    this.dataElement,
  });

  final PropKind kind;
  final bool isNullable;

  /// Set for [PropKind.enumeration].
  final EnumElement? enumElement;

  /// Set for [PropKind.data] and [PropKind.dataList]: the `@GenUiData` class.
  final ClassElement? dataElement;
}

/// Maps [type] to a [TypeMapping], or returns `null` when unsupported.
TypeMapping? mapType(DartType type) {
  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  if (type is FunctionType) {
    if (type.returnType is VoidType && type.formalParameters.isEmpty) {
      return TypeMapping(kind: PropKind.action, isNullable: isNullable);
    }
    return null;
  }

  if (type is! InterfaceType) return null;

  PropKind? kind;
  EnumElement? enumElement;
  ClassElement? dataElement;
  if (type.isDartCoreString) {
    kind = PropKind.string;
  } else if (type.isDartCoreInt) {
    kind = PropKind.integer;
  } else if (type.isDartCoreDouble) {
    kind = PropKind.decimal;
  } else if (type.isDartCoreNum) {
    kind = PropKind.number;
  } else if (type.isDartCoreBool) {
    kind = PropKind.boolean;
  } else if (type.element is EnumElement) {
    kind = PropKind.enumeration;
    enumElement = type.element as EnumElement;
  } else if (widgetChecker.isExactlyType(type)) {
    kind = PropKind.widget;
  } else if (type.isDartCoreList && type.typeArguments.length == 1) {
    final item = type.typeArguments.single;
    if (item.nullabilitySuffix == NullabilitySuffix.question) return null;
    if (item.isDartCoreString) {
      kind = PropKind.stringList;
    } else if (item.isDartCoreInt) {
      kind = PropKind.integerList;
    } else if (item.isDartCoreDouble) {
      kind = PropKind.decimalList;
    } else if (item.isDartCoreNum) {
      kind = PropKind.numberList;
    } else if (item.element is EnumElement) {
      kind = PropKind.enumerationList;
      enumElement = item.element as EnumElement;
    } else if (widgetChecker.isExactlyType(item)) {
      kind = PropKind.widgetList;
    } else {
      final itemData = dataClassOf(item);
      if (itemData != null) {
        kind = PropKind.dataList;
        dataElement = itemData;
      }
    }
  } else {
    dataElement = dataClassOf(type);
    if (dataElement != null) kind = PropKind.data;
  }

  if (kind == null) return null;
  return TypeMapping(
    kind: kind,
    isNullable: isNullable,
    enumElement: enumElement,
    dataElement: dataElement,
  );
}

/// The display name of the element type of a `List<T?>` whose `List<T>` form
/// *is* supported, or `null` otherwise.
///
/// Reported on its own rather than as "unsupported type": the JSON Schema for
/// a list has no way to say that one entry may be null, and the generated code
/// would have no value to build for it either, so nullability is the whole
/// problem and the fix is to drop the `?`. A list whose element type is not
/// supported in the first place falls through to the general message.
String? nullableListElement(DartType type) {
  if (type is! InterfaceType) return null;
  if (!type.isDartCoreList || type.typeArguments.length != 1) return null;
  final item = type.typeArguments.single;
  if (item.nullabilitySuffix != NullabilitySuffix.question) return null;
  final supported =
      item.isDartCoreString ||
      item.isDartCoreInt ||
      item.isDartCoreDouble ||
      item.isDartCoreNum ||
      item.element is EnumElement ||
      widgetChecker.isExactlyType(item) ||
      dataClassOf(item) != null;
  if (!supported) return null;
  return item.getDisplayString();
}

/// Whether [type] (or the element type of a `List`) failed to resolve.
///
/// The analyzer models an unresolvable type as `InvalidType`, which carries no
/// name and no library. Reported on its own rather than through the generic
/// "unsupported parameter type" message, because the cause is never the
/// generator's type table: it is a missing import, a typo, or a name that two
/// imports both provide.
bool hasUnresolvedType(DartType type) {
  if (type is InvalidType) return true;
  if (type is InterfaceType &&
      type.isDartCoreList &&
      type.typeArguments.length == 1) {
    return hasUnresolvedType(type.typeArguments.single);
  }
  return false;
}

/// The `@GenUiData` class behind [type], or `null` when [type] is not an
/// annotated data class.
ClassElement? dataClassOf(DartType type) {
  if (type is! InterfaceType) return null;
  final element = type.element;
  if (element is! ClassElement) return null;
  if (!genUiDataChecker.hasAnnotationOf(element)) return null;
  return element;
}

/// The name of a user-declared class that [type] refers to and that could be
/// made usable by adding `@GenUiData` to it, or `null`.
///
/// Used to turn "unsupported type" into an actionable message. Classes from
/// the SDK (`dart:` libraries) are never suggested: `Object` or `Duration`
/// cannot be annotated by the user.
String? annotatableClassName(DartType type) {
  if (type is! InterfaceType) return null;
  if (type.isDartCoreList && type.typeArguments.length == 1) {
    return annotatableClassName(type.typeArguments.single);
  }
  final element = type.element;
  if (element is! ClassElement) return null;
  if (element.library.uri.isScheme('dart')) return null;
  if (widgetChecker.isAssignableFrom(element)) return null;
  return element.name;
}

/// Human readable list of supported types, used in error messages.
const supportedTypesSummary =
    'String, int, double, num, bool, enums, a List of any of those, Widget, '
    'List<Widget>, VoidCallback / void Function(), a @GenUiData class and a '
    'List of one (each optionally nullable)';

/// Human readable list of the types allowed inside a `@GenUiData` class.
const supportedDataTypesSummary =
    'String, int, double, num, bool, enums, a List of any of those, a '
    '@GenUiData class and a List of one (each optionally nullable)';
