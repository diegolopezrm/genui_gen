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

/// Result of mapping a type: either a supported [kind] or `null`.
final class TypeMapping {
  const TypeMapping({
    required this.kind,
    required this.isNullable,
    this.enumElement,
  });

  final PropKind kind;
  final bool isNullable;

  /// Set for [PropKind.enumeration].
  final EnumElement? enumElement;
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
    } else if (widgetChecker.isExactlyType(item)) {
      kind = PropKind.widgetList;
    }
  }

  if (kind == null) return null;
  return TypeMapping(
    kind: kind,
    isNullable: isNullable,
    enumElement: enumElement,
  );
}

/// Human readable list of supported types, used in error messages.
const supportedTypesSummary =
    'String, int, double, num, bool, enums, List<String>, Widget, '
    'List<Widget>, VoidCallback / void Function() (each optionally nullable)';
