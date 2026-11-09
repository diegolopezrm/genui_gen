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
  out.writeln('  schema: ${_schema(spec, symbols)},');
  out.writeln(
    '  exampleData: [() => ${_exampleLiteral(buildExampleJson(spec))}],',
  );
  out.writeln('  builder: ${_widgetBuilder(spec, symbols)},');
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

/// The `checks` property, present only when the widget asked for the answer.
///
/// A list of `CheckRule`s, which is what makes the renderer evaluate them and
/// hand the result to the builder.
String _checksSchema(Set<String> symbols) {
  symbols.add('CommonSchemas');
  return "'checks': S.list(description: 'Validation rules for this "
      "component.', items: CommonSchemas.checkRule),";
}

/// [commonSchema], a `CommonSchemas` member, described by [description], a
/// Dart string literal, when there is one.
///
/// The members are values rather than functions, so a description is added by
/// copying the schema, the way a data class's schema gets a use-site
/// description.
String _common(String commonSchema, String? description, Set<String> symbols) {
  symbols.add('CommonSchemas');
  if (description == null) return 'CommonSchemas.$commonSchema';
  return 'S.fromMap({...CommonSchemas.$commonSchema.value, '
      "'description': $description})";
}

/// A literal of [literal]'s shape, a data binding or a function call, which is
/// what the renderer resolves a property of that shape from.
///
/// `anyOf` rather than `oneOf`, as in the `CommonSchemas` dynamic types: a
/// `{"path": ...}` is also an object, so it can match an object or map literal
/// with no required keys as well as the binding, and the renderer validates a
/// component before applying it.
String _literalOrReference(
  String literal,
  String description,
  Set<String> symbols,
) {
  symbols.add('CommonSchemas');
  final args = [
    if (description.isNotEmpty) description,
    'anyOf: [$literal, CommonSchemas.dataBinding, CommonSchemas.functionCall]',
  ].join(', ');
  return 'S.combined($args)';
}

String _schema(WidgetSpec spec, Set<String> symbols) {
  final out = StringBuffer('S.object(');
  out.write('description: ${dartWrappedString(spec.description)},');
  final properties = spec.schemaProps.toList();
  final written = spec.writtenProperties;
  final bool checkable = spec.checkProp != null;
  if (properties.isNotEmpty || checkable) {
    out.write('properties: {');
    for (final prop in properties) {
      final schema = _propertySchema(
        prop,
        symbols,
        isWritten: written.contains(prop.schemaName),
      );
      out.write('${dartString(prop.schemaName)}: $schema,');
    }
    if (checkable) out.write(_checksSchema(symbols));
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
/// the catalog document holds the component's schema as it is, and there is
/// no registry we control to resolve a reference against.
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

/// Appended to the description of a property some callback writes back to.
///
/// Without it the model has no way to know that binding the property to a path
/// is what makes the user's answer readable: the callback itself is not in the
/// schema, because the model does not supply it.
const _writeBackNote =
    'The component writes the value the user chooses back to this property, so '
    'bind it to a data path if you need to read the result.';

/// The schema one value of a `Map<String, V>` takes.
///
/// Plain `S.*` rather than a `CommonSchemas` form: the binding applies to the
/// map as a whole, the way it does for a list, so an individual value is a
/// literal.
String _mapValueSchema(PropSpec prop, Set<String> symbols) {
  symbols.add('S');
  return switch (prop.mapValueKind) {
    null => 'true',
    PropKind.string => 'S.string()',
    PropKind.integer => 'S.integer()',
    PropKind.decimal || PropKind.number => 'S.number()',
    PropKind.boolean => 'S.boolean()',
    PropKind.enumeration =>
      'S.string(enumValues: [${prop.enumValues.map(dartString).join(', ')}])',
    _ => throw StateError('${prop.mapValueKind} is not a map value'),
  };
}

/// The type arguments a `@GenUiProp` map lands in, without the `Map`.
String _mapTypeArguments(PropSpec prop) => switch (prop.mapValueKind) {
  null => '<String, Object?>',
  PropKind.string => '<String, String>',
  PropKind.integer => '<String, int>',
  PropKind.decimal => '<String, double>',
  PropKind.number => '<String, num>',
  PropKind.boolean => '<String, bool>',
  PropKind.enumeration => '<String, ${prop.enumTypeName}>',
  _ => throw StateError('${prop.mapValueKind} is not a map value'),
};

/// The full Dart type, for a type argument such as `genUiMissingField<...>`.
String _mapDartType(PropSpec prop) => 'Map${_mapTypeArguments(prop)}';

/// An empty map of that type, for a fallback.
String _mapEmptyLiteral(PropSpec prop) => 'const ${_mapTypeArguments(prop)}{}';

/// Reads a map out of [source], coercing its values.
///
/// An entry the model got wrong is dropped rather than defaulted: a map is a
/// set of keys the model chose, so a key it could not express is better
/// absent than present and wrong.
String _mapExpression(PropSpec prop, Set<String> symbols, String source) {
  switch (prop.mapValueKind) {
    case null:
      symbols.add('genUiAsObject');
      return 'genUiAsObject($source)';
    case PropKind.string:
      symbols.add('genUiAsStringMap');
      return 'genUiAsStringMap($source)';
    case PropKind.number:
      symbols.add('genUiAsNumMap');
      return 'genUiAsNumMap($source)';
    case PropKind.integer:
      symbols.add('genUiAsNumMap');
      return 'genUiAsNumMap($source)?.map('
          '(key, value) => MapEntry(key, value.toInt()))';
    case PropKind.decimal:
      symbols.add('genUiAsNumMap');
      return 'genUiAsNumMap($source)?.map('
          '(key, value) => MapEntry(key, value.toDouble()))';
    case PropKind.boolean:
      symbols.add('genUiAsBoolMap');
      return 'genUiAsBoolMap($source)';
    case PropKind.enumeration:
      symbols.add('genUiAsStringMap');
      final type = prop.enumTypeName!;
      // A name the enum does not declare is dropped, the same way it is in a
      // list of enums. The switch is what keeps the whole thing null when the
      // property never arrived, so a required one is still reported; a
      // `fromEntries` would hand back an empty map and say nothing.
      return '(switch (genUiAsStringMap($source)) { '
          'final Map<String, String> entries => <String, $type>{ '
          'for (final MapEntry<String, String> entry in entries.entries) '
          'if ($type.values.asNameMap()[entry.value] case final value?) '
          'entry.key: value, }, '
          '_ => null })';
    default:
      throw StateError('${prop.mapValueKind} is not a map value');
  }
}

String _propertySchema(
  PropSpec prop,
  Set<String> symbols, {
  bool isWritten = false,
}) {
  final text = [
    if (prop.description != null) prop.description!,
    if (isWritten) _writeBackNote,
  ].join(' ');
  final String? literal = text.isEmpty ? null : dartWrappedString(text);
  final description = literal == null ? '' : 'description: $literal';
  String common(String name) => _common(name, literal, symbols);
  switch (prop.kind) {
    case PropKind.string:
      return common('dynamicString');
    case PropKind.integer:
    case PropKind.decimal:
    case PropKind.number:
      return common('dynamicNumber');
    case PropKind.boolean:
      return common('dynamicBoolean');
    case PropKind.enumeration:
      // The constants, or a binding or a call that resolves to one of them.
      final values = prop.enumValues.map(dartString).join(', ');
      return _literalOrReference(
        'S.string(enumValues: [$values])',
        description,
        symbols,
      );
    case PropKind.stringList:
      return common('dynamicStringList');
    case PropKind.integerList:
    case PropKind.decimalList:
    case PropKind.numberList:
      // `CommonSchemas` has no numeric list, so the list is spelled out with
      // the same three forms `DynamicStringList` allows: a literal list, a
      // `{"path": ...}` and a `{"call": ...}`.
      return _literalOrReference(
        'S.list(items: S.number())',
        description,
        symbols,
      );
    case PropKind.enumerationList:
      final enumItemValues = prop.enumValues.map(dartString).join(', ');
      return _literalOrReference(
        'S.list(items: S.string(enumValues: [$enumItemValues]))',
        description,
        symbols,
      );
    case PropKind.map:
      // The keys are the model's to choose, so the schema constrains the
      // values and says nothing about the names.
      return _literalOrReference(
        'S.object(additionalProperties: ${_mapValueSchema(prop, symbols)})',
        description,
        symbols,
      );
    case PropKind.data:
      // The renderer resolves `{"path": ...}` and `{"call": ...}` as well as a
      // literal, so the schema has to allow all three. Same shape the core
      // catalog uses for `ChoicePicker.value`.
      return _literalOrReference(
        prop.data!.schemaVariableName,
        description,
        symbols,
      );
    case PropKind.dataList:
      return _literalOrReference(
        'S.list(items: ${prop.data!.schemaVariableName})',
        description,
        symbols,
      );
    case PropKind.widget:
      return common('componentId');
    case PropKind.widgetList:
      if (prop.isTemplate) {
        // Both shapes: the list of ids the agent writes out, and the template
        // it repeats over a path.
        return common('childList');
      }
      symbols.add('CommonSchemas');
      final args = [
        if (description.isNotEmpty) description,
        'items: CommonSchemas.componentId',
      ].join(', ');
      return 'S.list($args)';
    case PropKind.action:
      return common('action');
    case PropKind.valueWriter:
    case PropKind.checkResult:
      throw StateError('${prop.kind} is not a schema property');
  }
}

// --- Widget builder ------------------------------------------------------

/// The parameters of the generated builder, which is an a2ui_flutter
/// `ComponentWidgetBuilder`: the renderer hands it the properties already
/// resolved against the data model, and rebuilds it when one of them changes.
const _builderParameters = '(context, node, props, buildChild)';

String _widgetBuilder(WidgetSpec spec, Set<String> symbols) {
  if (spec.props.isEmpty) {
    return '$_builderParameters => ${spec.constructorReference}()';
  }

  final out = StringBuffer('$_builderParameters {\n');

  if (spec.requiredProps.isNotEmpty) {
    out.writeln(_missingHelper(spec, symbols));
  }

  if (spec.props.any((p) => p.kind.isData)) {
    out.writeln(_missingFieldHelper(spec, symbols));
  }

  // A component the agent may attach rules to reads what the renderer made of
  // them before anything else, so the answer is in scope for every property
  // that follows.
  if (spec.checkProp != null) {
    symbols.add('GenUiCheckResult');
    out.writeln('final $_checkLocal = GenUiCheckResult.of(props);');
  }

  out.writeln(
    'return ${spec.constructorReference}(${_arguments(spec, symbols)});',
  );
  out.write('}');
  return out.toString();
}

/// The name the evaluated result is bound to inside the generated builder.
const _checkLocal = 'checked';

/// A local helper that reports a missing required property through
/// `genUiReportMissing` (once per component instance, never for data
/// bindings that are still unresolved) and returns the fallback to use
/// instead. Never throws.
String _missingHelper(WidgetSpec spec, Set<String> symbols) {
  symbols.add('genUiReportMissing');
  return """
T missing<T>(String property, T fallback) {
  genUiReportMissing(node, ${dartString(spec.catalogName)}, property);
  return fallback;
}""";
}

/// A local helper that builds the reporter handed to a generated decoder, so
/// a required field the model left out of a data object is reported as
/// `<property>.<field>` rather than staying silent.
String _missingFieldHelper(WidgetSpec spec, Set<String> symbols) {
  symbols.addAll(['genUiReportMissing', 'GenUiMissingFieldReporter']);
  return 'GenUiMissingFieldReporter missingIn(String property) => '
      '(field) => genUiReportMissing(node, '
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

String _arguments(WidgetSpec spec, Set<String> symbols) {
  final out = StringBuffer();
  final written = spec.writtenProperties;
  String argument(PropSpec prop) =>
      _argument(prop, symbols, isWritten: written.contains(prop.schemaName));
  for (final prop in spec.props.where((p) => !p.isNamed)) {
    out.write('${argument(prop)}, ');
  }
  for (final prop in spec.props.where((p) => p.isNamed)) {
    out.write('${prop.dartName}: ${argument(prop)}, ');
  }
  return out.toString();
}

/// The expression passed to the constructor for [prop].
///
/// Every value is read from `props`, which the renderer has resolved, and
/// coerced through the `genUiAs*` helpers rather than cast. Required
/// properties fall back to a neutral value (and report through `missing`),
/// properties with a default fall back to that default so the Dart default
/// applies, and everything else is passed through as nullable.
///
/// `missing` always gets an explicit type argument: inside parentheses the
/// `??` operand would otherwise be inferred from the nullable left-hand side.
String _argument(PropSpec prop, Set<String> symbols, {bool isWritten = false}) {
  final key = dartString(prop.schemaName);

  /// The resolved value of the property. A property some callback writes to
  /// is read from where the callback writes it, so the control reflects what
  /// the user just did; until then that is the literal the model sent.
  String value() {
    if (!isWritten) return 'props.value($key)';
    symbols.add('genUiWrittenValue');
    return 'genUiWrittenValue(node, props, $key)';
  }

  String coerce(String helper) {
    symbols.add(helper);
    return '$helper(${value()})';
  }

  String withFallback(String value, String type, String fallback) {
    if (prop.isSchemaRequired) {
      return '$value ?? missing<$type>($key, $fallback)';
    }
    if (prop.defaultValueCode != null) {
      return '$value ?? ${_defaultExpression(prop)}';
    }
    return value;
  }

  /// The fallback of a property that is not a value, such as a child.
  String orElse(String type, String requiredFallback) {
    if (prop.isSchemaRequired) return 'missing<$type>($key, $requiredFallback)';
    if (prop.defaultValueCode != null) return _defaultExpression(prop);
    return 'null';
  }

  switch (prop.kind) {
    case PropKind.string:
      return withFallback(coerce('genUiAsString'), 'String', "''");
    case PropKind.integer:
      final intValue = coerce('genUiAsNum');
      if (prop.isSchemaRequired) {
        return '($intValue ?? missing<num>($key, 0)).toInt()';
      }
      return withFallback('$intValue?.toInt()', 'int', '0');
    case PropKind.decimal:
      final doubleValue = coerce('genUiAsNum');
      if (prop.isSchemaRequired) {
        return '($doubleValue ?? missing<num>($key, 0)).toDouble()';
      }
      return withFallback('$doubleValue?.toDouble()', 'double', '0');
    case PropKind.number:
      return withFallback(coerce('genUiAsNum'), 'num', '0');
    case PropKind.boolean:
      return withFallback(coerce('genUiAsBool'), 'bool', 'false');
    case PropKind.enumeration:
      final enumType = prop.enumTypeName!;
      return withFallback(
        '$enumType.values.asNameMap()[${coerce('genUiAsString')}]',
        enumType,
        '$enumType.values.first',
      );
    case PropKind.stringList:
      return withFallback(
        coerce('genUiAsStringList'),
        'List<String>',
        'const <String>[]',
      );
    case PropKind.integerList:
      return withFallback(
        '${coerce('genUiAsNumList')}?.map((n) => n.toInt()).toList()',
        'List<int>',
        'const <int>[]',
      );
    case PropKind.decimalList:
      return withFallback(
        '${coerce('genUiAsNumList')}?.map((n) => n.toDouble()).toList()',
        'List<double>',
        'const <double>[]',
      );
    case PropKind.numberList:
      return withFallback(
        coerce('genUiAsNumList'),
        'List<num>',
        'const <num>[]',
      );
    case PropKind.enumerationList:
      // A name the enum does not declare is dropped rather than defaulted:
      // the list is the model's, and one bad entry should not silently become
      // a valid value the author never wrote.
      final listEnumType = prop.enumTypeName!;
      return withFallback(
        '${coerce('genUiAsStringList')}?.map((name) => '
            '$listEnumType.values.asNameMap()[name]).nonNulls.toList()',
        'List<$listEnumType>',
        'const <$listEnumType>[]',
      );
    case PropKind.map:
      return withFallback(
        _mapExpression(prop, symbols, value()),
        _mapDartType(prop),
        _mapEmptyLiteral(prop),
      );
    case PropKind.data:
      final decoder = prop.data!.decoderName;
      final object = coerce('genUiAsObject');
      if (prop.isSchemaRequired) {
        // The reporter is passed only when the object actually resolved. A
        // `{"path": ...}` that has not resolved yet is reported once by
        // `missing`, which stays silent for a pending binding; decoding the
        // empty fallback with a reporter would instead send the model one
        // false `<property>.<field>` error per required field of a component
        // that was never malformed.
        return 'switch ($object) { '
            'final Map<String, Object?> json => '
            '$decoder(json, missingIn($key)), '
            '_ => $decoder('
            'missing<Map<String, Object?>>($key, const <String, Object?>{})) }';
      }
      final fallback = prop.defaultValueCode == null
          ? 'null'
          : _defaultExpression(prop);
      return 'switch ($object) { '
          'final Map<String, Object?> json => '
          '$decoder(json, missingIn($key)), '
          '_ => $fallback }';
    case PropKind.dataList:
      final type = prop.data!.className;
      return withFallback(
        '${coerce('genUiAsObjectList')}?.map((json) => '
            '${prop.data!.decoderName}(json, missingIn($key))).toList()',
        'List<$type>',
        'const <$type>[]',
      );
    case PropKind.widget:
      // The renderer has already turned the id into a node; a child it could
      // not resolve yet is a node too, which renders nothing until it can.
      if (prop.isSchemaRequired) symbols.addAll(['Widget', 'SizedBox']);
      final fallback = orElse('Widget', 'const SizedBox.shrink()');
      return 'switch (props.child($key)) { '
          'final child? => buildChild(child), '
          '_ => $fallback }';
    case PropKind.widgetList:
      // A list of ids and a template both arrive as a list of nodes, one per
      // child, the template's already expanded over its path.
      if (prop.isSchemaRequired) symbols.add('Widget');
      final fallback = orElse('List<Widget>', 'const <Widget>[]');
      return 'props.value($key) is List '
          '? [for (final child in props.children($key)) buildChild(child)] '
          ': $fallback';
    case PropKind.checkResult:
      return switch (prop.checkShape!) {
        CheckResultShape.message => '$_checkLocal.message',
        CheckResultShape.isValid => '$_checkLocal.isValid',
        CheckResultShape.result => _checkLocal,
      };
    case PropKind.valueWriter:
      // Not a schema property: the callback is derived from the one it writes
      // to, so the binding of *that* property is what carries the path.
      symbols.add('genUiValueWriter');
      final target = dartString(prop.writesProperty!);
      final encode = prop.writerValueKind == PropKind.enumeration
          // Enums travel as their name, the same way the reader maps them back
          // through `values.asNameMap()`.
          ? ', encode: (value) => value.name'
          : '';
      return 'genUiValueWriter<${prop.writerTypeName}>'
          '(node, props, $target$encode)';
    case PropKind.action:
      symbols.add('genUiActionHandler');
      return withFallback(
        'genUiActionHandler(props.action($key))',
        'void Function()',
        '() {}',
      );
  }
}

// --- Data classes --------------------------------------------------------

/// Emits the `ObjectSchema` and the decoder function for [spec].
///
/// Fields of a data class use the plain `S.*` schemas rather than the
/// `CommonSchemas.dynamic*` ones: the values inside a data object are literals
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
    '/// Values are coerced the same way the generated builder coerces a',
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
      // `CommonSchemas` only offers `dynamicNumber`.
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
    case PropKind.map:
      symbols.add('S');
      final mapArgs = [
        if (description.isNotEmpty) description,
        'additionalProperties: ${_mapValueSchema(field, symbols)}',
      ].join(', ');
      return 'S.object($mapArgs)';
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
    case PropKind.valueWriter:
    case PropKind.checkResult:
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
/// apply the very rules the generated builder applies to a widget property.
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
    case PropKind.map:
      return withFallback(
        _mapExpression(field, symbols, raw),
        _mapDartType(field),
        _mapEmptyLiteral(field),
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
    case PropKind.valueWriter:
    case PropKind.checkResult:
      throw StateError('${field.kind} is not valid inside a data class');
  }
}

/// Emits the `final FunctionImplementation <name>GenUiFunction = ...;`
/// declaration for [spec].
///
/// The body reads each argument out of the `args` map through the same
/// coercions a `@GenUiData` field uses, so a model that sends a string where a
/// number was declared degrades the way a widget property does rather than
/// throwing inside the expression that called the function.
EmittedCode emitFunction(FunctionSpec spec) {
  final symbols = <String>{
    'FunctionImplementation',
    'GenUiClientFunction',
    'A2uiReturnType',
    'S',
  };
  final out = StringBuffer();

  final String constructor = switch (spec.delivery) {
    FunctionDelivery.sync => 'GenUiClientFunction',
    FunctionDelivery.async => 'GenUiClientFunction.async',
    FunctionDelivery.streaming => 'GenUiClientFunction.streaming',
  };

  out
    ..writeln('/// Generated catalog function for [${spec.dartName}].')
    ..writeln(
      'final FunctionImplementation ${spec.variableName} = $constructor(',
    )
    ..writeln('  name: ${dartString(spec.functionName)},')
    ..writeln('  description: ${dartWrappedString(spec.description)},')
    ..writeln('  argumentSchema: ${_argumentSchema(spec, symbols)},')
    ..writeln('  returnType: A2uiReturnType.${spec.returns.constantName},')
    ..writeln('  body: (args, context) {');

  if (spec.args.isEmpty) {
    out.writeln('    return ${spec.dartName}();');
  } else {
    symbols.add('GenUiMissingFieldReporter');
    out
      ..writeln('    final json = args;')
      // The generated readers report a required argument the model left out
      // through this reporter. A function has no component to attribute it to,
      // so the fallback is taken silently, exactly as a widget property's is
      // when the data model has not arrived yet.
      ..writeln('    const GenUiMissingFieldReporter? onMissing = null;')
      ..writeln('    return ${spec.dartName}(');
    for (final arg in spec.args) {
      final value = _decodeArgument(arg, symbols);
      out.writeln(
        arg.isNamed ? '      ${arg.dartName}: $value,' : '      $value,',
      );
    }
    out.writeln('    );');
  }

  out
    ..writeln('  },')
    ..writeln(');');

  return EmittedCode(out.toString(), symbols);
}

String _argumentSchema(FunctionSpec spec, Set<String> symbols) {
  if (spec.args.isEmpty) return 'S.object(properties: {})';

  final out = StringBuffer('S.object(\n    properties: {\n');
  for (final arg in spec.args) {
    out.writeln(
      '      ${dartString(arg.schemaName)}: '
      '${_propertySchema(arg, symbols)},',
    );
  }
  out.write('    },\n');
  final required = spec.args
      .where((arg) => arg.isSchemaRequired)
      .map((arg) => dartString(arg.schemaName))
      .toList();
  if (required.isNotEmpty) {
    out.writeln('    required: [${required.join(', ')}],');
  }
  out.write('  )');
  return out.toString();
}
