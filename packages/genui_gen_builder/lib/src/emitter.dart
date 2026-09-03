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
      out.write(
        '${dartString(prop.schemaName)}: ${_propertySchema(prop, symbols)},',
      );
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

/// The inlined schema for a *field* whose type is a `@GenUiData` class.
///
/// The nested class's own generated `ObjectSchema` variable is referenced, so
/// the JSON produced is the fully inlined object schema and never a `$ref` —
/// `A2uiSchemas.updateComponentsSchema` consumes `dataSchema` as a `oneOf`
/// branch and there is no registry we control to resolve a reference against.
///
/// When the use site carries its own description — a doc comment or
/// `@GenUiProp(description:)` on the parameter — the schema is copied with
/// that description in place of the data class's own, so one field can explain
/// what the object means *here* without changing the shared class. Without a
/// use-site description the variable is referenced as-is.
///
/// A widget *property* does not go through here: it needs the literal wrapped
/// in a union with the data-binding and function-call forms, and carries its
/// description on that wrapper (see [_propertySchema]).
String _objectSchema(DataSpec data, String? description, Set<String> symbols) {
  final variable = data.schemaVariableName;
  if (description == null) return variable;
  symbols.add('ObjectSchema');
  return 'ObjectSchema.fromMap({...$variable.value, '
      "'description': ${dartWrappedString(description)}})";
}

String _propertySchema(PropSpec prop, Set<String> symbols) {
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
    case PropKind.integerList:
    case PropKind.decimalList:
    case PropKind.numberList:
      // `A2uiSchemas` has no numeric array reference, so the list is built
      // from `listOrReference`, the same helper `dataList` uses: it allows a
      // literal list, a `{"path": ...}` and a `{"call": ...}`, which is what
      // `BoundList` resolves.
      symbols.add('S');
      final numberItems = [
        if (description.isNotEmpty) description,
        'items: S.number()',
      ].join(', ');
      return 'A2uiSchemas.listOrReference($numberItems)';
    case PropKind.enumerationList:
      symbols.add('S');
      final enumItemValues = prop.enumValues.map(dartString).join(', ');
      final enumItems = [
        if (description.isNotEmpty) description,
        'items: S.string(enumValues: [$enumItemValues])',
      ].join(', ');
      return 'A2uiSchemas.listOrReference($enumItems)';
    case PropKind.data:
      // Folded through `BoundObject`, which resolves `{"path": ...}` and
      // `{"call": ...}` as well as a literal, so the schema has to allow all
      // three. Same shape the core catalog uses for `ChoicePicker.value`.
      final objectArgs = [
        if (description.isNotEmpty) description,
        'oneOf: [${prop.data!.schemaVariableName}, '
            'A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()]',
      ].join(', ');
      return 'S.combined($objectArgs)';
    case PropKind.dataList:
      // Folded through `BoundList`, so the same three forms apply;
      // `listOrReference` is the core helper for exactly that.
      final args = [
        if (description.isNotEmpty) description,
        'items: ${prop.data!.schemaVariableName}',
      ].join(', ');
      return 'A2uiSchemas.listOrReference($args)';
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

  if (spec.props.any((p) => p.kind.isData)) {
    out.writeln(_missingFieldHelper(spec, symbols));
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

/// A local helper that builds the reporter handed to a generated decoder, so
/// a required field the model left out of a data object is reported as
/// `<property>.<field>` rather than staying silent.
String _missingFieldHelper(WidgetSpec spec, Set<String> symbols) {
  symbols.addAll(['genUiReportMissing', 'GenUiMissingFieldReporter']);
  return 'GenUiMissingFieldReporter missingIn(String property) => '
      '(field) => genUiReportMissing(ctx, '
      '${dartString(spec.catalogName)}'
      r""", '$property.$field');""";
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
  PropKind.stringList || PropKind.enumerationList => 'stringList',
  PropKind.integerList ||
  PropKind.decimalList ||
  PropKind.numberList => 'numberList',
  PropKind.data => 'object',
  PropKind.dataList => 'objectList',
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
    case PropKind.integerList:
      return withFallback(
        'v.numberList($key)?.map((n) => n.toInt()).toList()',
        'List<int>',
        'const <int>[]',
      );
    case PropKind.decimalList:
      return withFallback(
        'v.numberList($key)?.map((n) => n.toDouble()).toList()',
        'List<double>',
        'const <double>[]',
      );
    case PropKind.numberList:
      return withFallback('v.numberList($key)', 'List<num>', 'const <num>[]');
    case PropKind.enumerationList:
      // A name the enum does not declare is dropped rather than defaulted:
      // the list is the model's, and one bad entry should not silently become
      // a valid value the author never wrote.
      final listEnumType = prop.enumTypeName!;
      return withFallback(
        'v.stringList($key)?.map((name) => '
            '$listEnumType.values.asNameMap()[name]).nonNulls.toList()',
        'List<$listEnumType>',
        'const <$listEnumType>[]',
      );
    case PropKind.data:
      final decoder = prop.data!.decoderName;
      if (prop.isSchemaRequired) {
        // The reporter is passed only when the object actually resolved. A
        // `{"path": ...}` that has not resolved yet is reported once by
        // `missing`, which stays silent for a pending binding; decoding the
        // empty fallback with a reporter would instead send the model one
        // false `<property>.<field>` error per required field of a component
        // that was never malformed.
        return 'switch (v.object($key)) { '
            'final Map<String, Object?> json => '
            '$decoder(json, missingIn($key)), '
            '_ => $decoder('
            'missing<JsonMap>($key, const <String, Object?>{})) }';
      }
      final fallback = prop.defaultValueCode == null
          ? 'null'
          : _defaultExpression(prop);
      return 'switch (v.object($key)) { '
          'final Map<String, Object?> json => '
          '$decoder(json, missingIn($key)), '
          '_ => $fallback }';
    case PropKind.dataList:
      final type = prop.data!.className;
      return withFallback(
        'v.objectList($key)?.map((json) => '
            '${prop.data!.decoderName}(json, missingIn($key))).toList()',
        'List<$type>',
        'const <$type>[]',
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

// --- Data classes --------------------------------------------------------

/// Emits the `ObjectSchema` and the decoder function for [spec].
///
/// Fields of a data class use the plain `S.*` schemas rather than the
/// `A2uiSchemas.*Reference` ones: the values inside a data object are literals
/// the model emits, not per-field data bindings. The binding applies to the
/// whole object, which is the widget property that carries it.
EmittedCode emitDataClass(DataSpec spec) {
  final symbols = <String>{'ObjectSchema', 'GenUiMissingFieldReporter'};
  final out = StringBuffer();

  out.writeln('/// Generated schema for [${spec.className}].');
  out.writeln(
    'final ObjectSchema ${spec.schemaVariableName} = '
    '${_dataSchema(spec, symbols)};',
  );
  out.writeln();
  out.writeln(
    '/// Decodes a [${spec.className}] from the map the model produced.',
  );
  out.writeln('///');
  out.writeln(
    '/// Values are coerced the same way genui\'s `Bound*` widgets coerce a',
  );
  out.writeln(
    '/// widget property, so a field of the wrong type degrades instead of',
  );
  out.writeln(
    '/// throwing. Every required field that had to fall back is reported',
  );
  out.writeln('/// through [onMissing], when one is given.');
  out.write(
    '${spec.className} ${spec.decoderName}(Map<String, Object?> json, '
    '[GenUiMissingFieldReporter? onMissing]) => '
    '${spec.constructorReference}(${_decodeArguments(spec, symbols)});',
  );

  return EmittedCode(out.toString(), symbols);
}

/// The schema literal for a data class.
///
/// `ObjectSchema(...)` rather than `S.object(...)`: the redirecting factory
/// `Schema.object` is statically typed as `Schema`, so it cannot initialise
/// the `ObjectSchema` variable the generated code declares. Both build the
/// very same schema.
String _dataSchema(DataSpec spec, Set<String> symbols) {
  final out = StringBuffer('ObjectSchema(');
  if (spec.description != null) {
    out.write('description: ${dartWrappedString(spec.description!)},');
  }
  if (spec.fields.isNotEmpty) {
    out.write('properties: {');
    for (final field in spec.fields) {
      out.write(
        '${dartString(field.schemaName)}: ${_fieldSchema(field, symbols)},',
      );
    }
    out.write('},');
    final required = spec.requiredFields.toList();
    if (required.isNotEmpty) {
      out.write('required: [');
      out.write(required.map((f) => dartString(f.schemaName)).join(', '));
      out.write('],');
    }
  }
  out.write(')');
  return out.toString();
}

String _fieldSchema(PropSpec field, Set<String> symbols) {
  final description = field.description == null
      ? ''
      : 'description: ${dartWrappedString(field.description!)}';
  if (!field.kind.isData) symbols.add('S');
  switch (field.kind) {
    case PropKind.string:
      return 'S.string($description)';
    case PropKind.integer:
      // A field of a data class is a literal the model emits, so the schema
      // can say "integer" and have it validated. A widget property cannot:
      // `A2uiSchemas` only offers `numberReference`.
      return 'S.integer($description)';
    case PropKind.decimal:
    case PropKind.number:
      return 'S.number($description)';
    case PropKind.boolean:
      return 'S.boolean($description)';
    case PropKind.enumeration:
      final values = field.enumValues.map(dartString).join(', ');
      final args = [
        if (description.isNotEmpty) description,
        'enumValues: [$values]',
      ].join(', ');
      return 'S.string($args)';
    case PropKind.stringList:
      final args = [
        if (description.isNotEmpty) description,
        'items: S.string()',
      ].join(', ');
      return 'S.list($args)';
    case PropKind.integerList:
      // As with a scalar field, a data class field is a literal the model
      // emits, so the item schema can say "integer" and be validated.
      final intArgs = [
        if (description.isNotEmpty) description,
        'items: S.integer()',
      ].join(', ');
      return 'S.list($intArgs)';
    case PropKind.decimalList:
    case PropKind.numberList:
      final numArgs = [
        if (description.isNotEmpty) description,
        'items: S.number()',
      ].join(', ');
      return 'S.list($numArgs)';
    case PropKind.enumerationList:
      final enumFieldValues = field.enumValues.map(dartString).join(', ');
      final enumArgs = [
        if (description.isNotEmpty) description,
        'items: S.string(enumValues: [$enumFieldValues])',
      ].join(', ');
      return 'S.list($enumArgs)';
    case PropKind.data:
      return _objectSchema(field.data!, field.description, symbols);
    case PropKind.dataList:
      symbols.add('S');
      final args = [
        if (description.isNotEmpty) description,
        'items: ${field.data!.schemaVariableName}',
      ].join(', ');
      return 'S.list($args)';
    case PropKind.widget:
    case PropKind.widgetList:
    case PropKind.action:
      throw StateError('${field.kind} is not valid inside a data class');
  }
}

String _decodeArguments(DataSpec spec, Set<String> symbols) {
  final out = StringBuffer();
  for (final field in spec.fields.where((f) => !f.isNamed)) {
    out.write('${_decodeArgument(field, symbols)}, ');
  }
  for (final field in spec.fields.where((f) => f.isNamed)) {
    out.write('${field.dartName}: ${_decodeArgument(field, symbols)}, ');
  }
  return out.toString();
}

/// The expression that reads one field out of the decoded JSON map.
///
/// Nothing is cast: the raw value goes through the `genUiAs*` coercions, which
/// apply the very rules genui's `Bound*` widgets apply to a widget property.
/// A model that puts a number where a string was declared therefore degrades
/// the same way in both places instead of throwing a `TypeError` inside
/// `build`.
///
/// Required fields fall back to the same neutral values the widget builder
/// uses and report through `onMissing`, fields with a default fall back to
/// that default, and everything else stays nullable.
String _decodeArgument(PropSpec field, Set<String> symbols) {
  final key = dartString(field.schemaName);
  final raw = 'json[$key]';

  // The type argument is always explicit: inside parentheses the `??` operand
  // would otherwise be inferred from the literal fallback (`0` gives `int`,
  // not `num`) and the result would not accept `.toDouble()`.
  String reportMissing(String type, String fallback) {
    symbols.add('genUiMissingField');
    return 'genUiMissingField<$type>(onMissing, $key, $fallback)';
  }

  String withFallback(String value, String type, String fallback) {
    if (field.isSchemaRequired) {
      return '$value ?? ${reportMissing(type, fallback)}';
    }
    if (field.defaultValueCode != null) {
      return '$value ?? ${_defaultExpression(field)}';
    }
    return value;
  }

  String orElse(String type, String requiredFallback) {
    if (field.isSchemaRequired) return reportMissing(type, requiredFallback);
    if (field.defaultValueCode != null) return _defaultExpression(field);
    return 'null';
  }

  switch (field.kind) {
    case PropKind.string:
      symbols.add('genUiAsString');
      return withFallback('genUiAsString($raw)', 'String', "''");
    case PropKind.integer:
      symbols.add('genUiAsNum');
      if (field.isSchemaRequired) {
        return '(genUiAsNum($raw) ?? ${reportMissing('num', '0')}).toInt()';
      }
      return withFallback('genUiAsNum($raw)?.toInt()', 'int', '0');
    case PropKind.decimal:
      symbols.add('genUiAsNum');
      if (field.isSchemaRequired) {
        return '(genUiAsNum($raw) ?? ${reportMissing('num', '0')}).toDouble()';
      }
      return withFallback('genUiAsNum($raw)?.toDouble()', 'double', '0');
    case PropKind.number:
      symbols.add('genUiAsNum');
      return withFallback('genUiAsNum($raw)', 'num', '0');
    case PropKind.boolean:
      symbols.add('genUiAsBool');
      return withFallback('genUiAsBool($raw)', 'bool', 'false');
    case PropKind.enumeration:
      symbols.add('genUiAsString');
      final enumType = field.enumTypeName!;
      return withFallback(
        '$enumType.values.asNameMap()[genUiAsString($raw)]',
        enumType,
        '$enumType.values.first',
      );
    case PropKind.stringList:
      symbols.add('genUiAsStringList');
      return withFallback(
        'genUiAsStringList($raw)',
        'List<String>',
        'const <String>[]',
      );
    case PropKind.integerList:
      symbols.add('genUiAsNumList');
      return withFallback(
        'genUiAsNumList($raw)?.map((n) => n.toInt()).toList()',
        'List<int>',
        'const <int>[]',
      );
    case PropKind.decimalList:
      symbols.add('genUiAsNumList');
      return withFallback(
        'genUiAsNumList($raw)?.map((n) => n.toDouble()).toList()',
        'List<double>',
        'const <double>[]',
      );
    case PropKind.numberList:
      symbols.add('genUiAsNumList');
      return withFallback('genUiAsNumList($raw)', 'List<num>', 'const <num>[]');
    case PropKind.enumerationList:
      symbols.add('genUiAsStringList');
      final listEnumType = field.enumTypeName!;
      return withFallback(
        'genUiAsStringList($raw)?.map((name) => '
            '$listEnumType.values.asNameMap()[name]).nonNulls.toList()',
        'List<$listEnumType>',
        'const <$listEnumType>[]',
      );
    case PropKind.data:
      symbols.addAll(['genUiAsObject', 'genUiNestedField']);
      final decoder = field.data!.decoderName;
      final orElseCode = orElse(
        field.data!.className,
        '$decoder(const <String, Object?>{})',
      );
      return 'switch (genUiAsObject($raw)) { '
          'final Map<String, Object?> nested => '
          '$decoder(nested, genUiNestedField(onMissing, $key)), '
          '_ => $orElseCode }';
    case PropKind.dataList:
      symbols.addAll(['genUiAsObjectList', 'genUiNestedField']);
      final decoder = field.data!.decoderName;
      final type = field.data!.className;
      return withFallback(
        'genUiAsObjectList($raw)?.map((nested) => '
            '$decoder(nested, genUiNestedField(onMissing, $key))).toList()',
        'List<$type>',
        'const <$type>[]',
      );
    case PropKind.widget:
    case PropKind.widgetList:
    case PropKind.action:
      throw StateError('${field.kind} is not valid inside a data class');
  }
}
