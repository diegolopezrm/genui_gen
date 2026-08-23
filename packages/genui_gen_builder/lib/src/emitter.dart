/// Turns a [WidgetSpec] into the Dart source of a `CatalogItem`.
///
/// Output is plain text; `source_gen` runs `dart format` on the whole part
/// file afterwards, so the emitter only has to produce valid Dart, not pretty
/// Dart.
library;

import 'example.dart';
import 'spec.dart';
import 'strings.dart';

/// Generated source plus the external identifiers it references.
///
/// The generator uses [symbols] to verify that every identifier resolves in
/// the annotated library (the output is a `part of` that library, so it
/// inherits its imports) and to tell the user exactly which imports are
/// missing otherwise.
final class EmittedCode {
  EmittedCode(this.source, this.symbols);

  final String source;
  final Set<String> symbols;
}

/// Emits the `final CatalogItem <name>CatalogItem = CatalogItem(...);`
/// declaration for [spec].
EmittedCode emitCatalogItem(WidgetSpec spec) {
  final symbols = <String>{'CatalogItem', 'S'};
  final out = StringBuffer();

  out.writeln('/// Generated [CatalogItem] for [${spec.className}].');
  out.writeln('final CatalogItem ${spec.variableName} = CatalogItem(');
  out.writeln('  name: ${dartString(spec.catalogName)},');
  if (spec.isImplicitlyFlexible) {
    out.writeln('  isImplicitlyFlexible: true,');
  }
  out.writeln('  dataSchema: ${_schema(spec, symbols)},');
  out.writeln(
    '  exampleData: [() => ${_exampleLiteral(buildExampleJson(spec))}],',
  );
  out.writeln('  widgetBuilder: ${_widgetBuilder(spec, symbols)},');
  out.write(');');

  return EmittedCode(out.toString(), symbols);
}

/// Renders the example JSON as a readable multi-line raw string literal.
///
/// Falls back to a single-line escaped literal in the unlikely event that the
/// JSON contains a triple quote, which a raw string cannot express.
String _exampleLiteral(String json) {
  if (json.contains("'''")) return dartString(json);
  return "r'''\n$json'''";
}

// --- Schema --------------------------------------------------------------

String _schema(WidgetSpec spec, Set<String> symbols) {
  final out = StringBuffer('S.object(');
  out.write('description: ${dartWrappedString(spec.description)},');
  if (spec.props.isNotEmpty) {
    symbols.add('A2uiSchemas');
    out.write('properties: {');
    for (final prop in spec.props) {
      out.write('${dartString(prop.schemaName)}: ${_propertySchema(prop)},');
    }
    out.write('},');
    final required = spec.requiredProps.toList();
    if (required.isNotEmpty) {
      out.write('required: [');
      out.write(required.map((p) => dartString(p.schemaName)).join(', '));
      out.write('],');
    }
  }
  out.write(')');
  return out.toString();
}

String _propertySchema(PropSpec prop) {
  final description = prop.description == null
      ? ''
      : 'description: ${dartWrappedString(prop.description!)}';
  switch (prop.kind) {
    case PropKind.string:
      return 'A2uiSchemas.stringReference($description)';
    case PropKind.integer:
    case PropKind.decimal:
    case PropKind.number:
      return 'A2uiSchemas.numberReference($description)';
    case PropKind.boolean:
      return 'A2uiSchemas.booleanReference($description)';
    case PropKind.enumeration:
      final values = prop.enumValues.map(dartString).join(', ');
      final args = [
        if (description.isNotEmpty) description,
        'enumValues: [$values]',
      ].join(', ');
      return 'A2uiSchemas.stringReference($args)';
    case PropKind.stringList:
      return 'A2uiSchemas.stringArrayReference($description)';
    case PropKind.widget:
      return 'A2uiSchemas.componentReference($description)';
    case PropKind.widgetList:
      final args = [
        if (description.isNotEmpty) description,
        'items: A2uiSchemas.componentReference()',
      ].join(', ');
      return 'S.list($args)';
    case PropKind.action:
      return 'A2uiSchemas.action($description)';
  }
}

// --- Widget builder ------------------------------------------------------

String _widgetBuilder(WidgetSpec spec, Set<String> symbols) {
  if (spec.props.isEmpty) {
    return '(ctx) => ${spec.constructorReference}()';
  }

  symbols.add('JsonMap');
  final out = StringBuffer('(ctx) {\n');
  out.writeln('final data = ctx.data as JsonMap;');

  if (spec.requiredProps.isNotEmpty) {
    out.writeln(_missingHelper(spec, symbols));
  }

  for (final prop in spec.childProps) {
    out.writeln(
      'final ${_childLocal(prop)} = data[${dartString(prop.schemaName)}];',
    );
  }

  final construction =
      '${spec.constructorReference}(${_arguments(spec, symbols)})';

  final bound = spec.boundProps.toList();
  if (bound.isEmpty) {
    out.writeln('return $construction;');
  } else {
    symbols.addAll(['GenUiBindings', 'GenUiBinding']);
    out.writeln('return GenUiBindings(');
    out.writeln('dataContext: ctx.dataContext,');
    out.writeln('bindings: {');
    for (final prop in bound) {
      final key = dartString(prop.schemaName);
      out.writeln('$key: GenUiBinding.${_bindingFactory(prop)}(data[$key]),');
    }
    out.writeln('},');
    out.writeln('builder: (context, v) => $construction,');
    out.writeln(');');
  }
  out.write('}');
  return out.toString();
}

/// A local helper that reports a missing required property through
/// `genUiReportMissing` (once per component instance, never for data
/// bindings that are still unresolved) and returns the fallback to use
/// instead. Never throws.
String _missingHelper(WidgetSpec spec, Set<String> symbols) {
  symbols.add('genUiReportMissing');
  return '''
T missing<T>(String property, T fallback) {
  genUiReportMissing(ctx, ${dartString(spec.catalogName)}, property);
  return fallback;
}''';
}

/// The default value of [prop] as an expression that is safe to place after
/// `??` or `:`.
///
/// Anything that is not a single literal, a (dotted) identifier or a plain
/// `const` expression is wrapped in parentheses: `kFlag ? 1 : 2` after `??`
/// would otherwise parse as `(x ?? kFlag) ? 1 : 2`.
String _defaultExpression(PropSpec prop) {
  final code = prop.defaultValueCode!;
  if (_atomicDefault.hasMatch(code)) return code;
  return '($code)';
}

final _atomicDefault = RegExp(
  r"""^([A-Za-z0-9_.]+|'[^'$\\]*'|"[^"$\\]*"|const\s[^?:]*)$""",
);

String _childLocal(PropSpec prop) => '_${prop.dartName}';

String _bindingFactory(PropSpec prop) => switch (prop.kind) {
  PropKind.string || PropKind.enumeration => 'string',
  PropKind.integer || PropKind.decimal || PropKind.number => 'number',
  PropKind.boolean => 'bool',
  PropKind.stringList => 'stringList',
  PropKind.widget ||
  PropKind.widgetList ||
  PropKind.action => throw StateError('${prop.kind} is not a bound property'),
};

String _arguments(WidgetSpec spec, Set<String> symbols) {
  final out = StringBuffer();
  for (final prop in spec.props.where((p) => !p.isNamed)) {
    out.write('${_argument(prop, symbols)}, ');
  }
  for (final prop in spec.props.where((p) => p.isNamed)) {
    out.write('${prop.dartName}: ${_argument(prop, symbols)}, ');
  }
  return out.toString();
}

/// The expression passed to the constructor for [prop].
///
/// Required properties fall back to a neutral value (and report through
/// `missing`), properties with a default fall back to that default so the
/// Dart default applies, and everything else is passed through as nullable.
///
/// `missing` always gets an explicit type argument: inside parentheses the
/// `??` operand would otherwise be inferred from the nullable left-hand side.
String _argument(PropSpec prop, Set<String> symbols) {
  final key = dartString(prop.schemaName);

  String withFallback(String value, String type, String fallback) {
    if (prop.isSchemaRequired) {
      return '$value ?? missing<$type>($key, $fallback)';
    }
    if (prop.defaultValueCode != null) {
      return '$value ?? ${_defaultExpression(prop)}';
    }
    return value;
  }

  switch (prop.kind) {
    case PropKind.string:
      return withFallback("v.string($key)", 'String', "''");
    case PropKind.integer:
      if (prop.isSchemaRequired) {
        return '(v.number($key) ?? missing<num>($key, 0)).toInt()';
      }
      return withFallback('v.number($key)?.toInt()', 'int', '0');
    case PropKind.decimal:
      if (prop.isSchemaRequired) {
        return '(v.number($key) ?? missing<num>($key, 0)).toDouble()';
      }
      return withFallback('v.number($key)?.toDouble()', 'double', '0');
    case PropKind.number:
      return withFallback('v.number($key)', 'num', '0');
    case PropKind.boolean:
      return withFallback('v.boolean($key)', 'bool', 'false');
    case PropKind.enumeration:
      final enumType = prop.enumTypeName!;
      return withFallback(
        '$enumType.values.asNameMap()[v.string($key)]',
        enumType,
        '$enumType.values.first',
      );
    case PropKind.stringList:
      return withFallback(
        'v.stringList($key)',
        'List<String>',
        'const <String>[]',
      );
    case PropKind.widget:
      final local = _childLocal(prop);
      final String fallback;
      if (prop.isSchemaRequired) {
        symbols.addAll(['Widget', 'SizedBox']);
        fallback = 'missing<Widget>($key, const SizedBox.shrink())';
      } else {
        fallback = prop.defaultValueCode == null
            ? 'null'
            : _defaultExpression(prop);
      }
      return '$local is String ? ctx.buildChild($local) : $fallback';
    case PropKind.widgetList:
      final local = _childLocal(prop);
      final String fallback;
      if (prop.isSchemaRequired) {
        symbols.add('Widget');
        fallback = 'missing<List<Widget>>($key, const <Widget>[])';
      } else {
        fallback = prop.defaultValueCode == null
            ? 'null'
            : _defaultExpression(prop);
      }
      return '$local is List '
          '? $local.whereType<String>().map((id) => ctx.buildChild(id)).toList() '
          ': $fallback';
    case PropKind.action:
      symbols.add('genUiActionHandler');
      return withFallback(
        'genUiActionHandler(ctx, data[$key])',
        'void Function()',
        '() {}',
      );
  }
}
