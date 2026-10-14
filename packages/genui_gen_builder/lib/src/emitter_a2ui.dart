/// Turns a [WidgetSpec] into the Dart source of an a2ui_flutter
/// `ComponentImplementation`, and a [FunctionSpec] into a
/// `FunctionImplementation`.
///
/// `emitter.dart` does the same for genui. The analysis, the data classes and
/// the coercions are shared; what differs is who resolves a property. genui
/// hands the builder the raw JSON, so the code generated for it binds every
/// property itself. a2ui_core resolves a component against its schema before
/// the builder runs: a dynamic value arrives as a binding, an action as a
/// closure, a child reference as a node, and the `checks` as `isValid` and
/// `validationErrors`. The code generated here only reads them, which is why
/// the schema has to use the shapes a2ui_core recognises.
library;

import 'emitter.dart';
import 'spec.dart';
import 'strings.dart';

/// Emits the `final ComponentImplementation <name>CatalogItem = ...;`
/// declaration for [spec].
///
/// The variable keeps the name it has on genui, so an app that moves across
/// renames nothing it wrote by hand.
EmittedCode emitComponentImplementation(WidgetSpec spec) {
  final symbols = <String>{'ComponentImplementation', 'GenUiSchemas'};
  final out = StringBuffer()
    ..writeln(
      '/// Generated [ComponentImplementation] for [${spec.className}].',
    )
    ..writeln(
      'final ComponentImplementation ${spec.variableName} = '
      'ComponentImplementation(',
    )
    ..writeln('  name: ${dartString(spec.catalogName)},')
    ..writeln('  schema: ${_schema(spec, symbols)},')
    ..writeln('  builder: ${_builder(spec, symbols)},')
    ..write(');');
  return EmittedCode(out.toString(), symbols);
}

// --- Schema --------------------------------------------------------------

/// The component schema.
///
/// `GenUiSchemas.component` adds the properties every component of the basic
/// catalog takes, `accessibility` and `weight`, so a generated component can
/// sit in a basic `Row` with a weight and carry a label like any other.
String _schema(WidgetSpec spec, Set<String> symbols) {
  final out = StringBuffer('GenUiSchemas.component(');
  out.write('description: ${dartWrappedString(spec.description)},');
  final properties = spec.schemaProps.toList();
  final written = spec.writtenProperties;
  final bool checkable = spec.checkProp != null;
  if (properties.isNotEmpty || checkable) {
    out.write('properties: {');
    for (final prop in properties) {
      final schema = propertySchemaA2ui(
        prop,
        symbols,
        isWritten: written.contains(prop.schemaName),
      );
      out.write('${dartString(prop.schemaName)}: $schema,');
    }
    if (checkable) out.write("'checks': GenUiSchemas.checks(),");
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

/// The schema of one property, or of one function argument.
///
/// Each shape is one a2ui_core recognises: a dynamic value is marked as
/// `DynamicString`, `DynamicNumber` and so on, or offers the data binding and
/// function call alongside its literal; a child is a `ComponentId`, a list of
/// children a `ChildList`; an action an `Action`. That marking is what makes
/// the node resolver hand the builder a binding, a node or a closure.
String propertySchemaA2ui(
  PropSpec prop,
  Set<String> symbols, {
  bool isWritten = false,
}) {
  final text = [
    if (prop.description != null) prop.description!,
    if (isWritten) writeBackNote,
  ].join(' ');
  final description = text.isEmpty
      ? ''
      : 'description: ${dartWrappedString(text)}';
  String withItems(String items) =>
      [if (description.isNotEmpty) description, items].join(', ');
  switch (prop.kind) {
    case PropKind.string:
      return 'GenUiSchemas.string($description)';
    case PropKind.integer:
    case PropKind.decimal:
    case PropKind.number:
      return 'GenUiSchemas.number($description)';
    case PropKind.boolean:
      return 'GenUiSchemas.boolean($description)';
    case PropKind.enumeration:
      final values = prop.enumValues.map(dartString).join(', ');
      return 'GenUiSchemas.string(${withItems('enumValues: [$values]')})';
    case PropKind.stringList:
      return 'GenUiSchemas.stringList($description)';
    case PropKind.integerList:
    case PropKind.decimalList:
    case PropKind.numberList:
      symbols.add('S');
      return 'GenUiSchemas.list(${withItems('items: S.number()')})';
    case PropKind.enumerationList:
      symbols.add('S');
      final values = prop.enumValues.map(dartString).join(', ');
      return 'GenUiSchemas.list('
          '${withItems('items: S.string(enumValues: [$values])')})';
    case PropKind.map:
      symbols.add('S');
      return 'GenUiSchemas.object(${withItems('literal: S.object('
      'additionalProperties: ${mapValueSchema(prop, symbols)})')})';
    case PropKind.data:
      return 'GenUiSchemas.object('
          '${withItems('literal: ${prop.data!.schemaVariableName}')})';
    case PropKind.dataList:
      return 'GenUiSchemas.list('
          '${withItems('items: ${prop.data!.schemaVariableName}')})';
    case PropKind.widget:
      return 'GenUiSchemas.componentId($description)';
    case PropKind.widgetList:
      // A template list takes both shapes, ids and `{componentId, path}`,
      // which is what `ChildList` is. A plain one keeps to ids, so the schema
      // the agent composes against says no more than the widget accepts.
      return prop.isTemplate
          ? 'GenUiSchemas.childList($description)'
          : 'GenUiSchemas.componentIdList($description)';
    case PropKind.action:
      return 'GenUiSchemas.action($description)';
    case PropKind.valueWriter:
    case PropKind.checkResult:
      throw StateError('${prop.kind} is not a schema property');
  }
}

// --- Widget builder ------------------------------------------------------

/// The builder closure.
///
/// Its parameters are named after the ones a2ui_flutter documents:
/// `context`, `node`, `props` and `buildChild`. Every argument is an
/// expression over them, so the closure declares no locals that a parameter
/// of the widget could collide with.
String _builder(WidgetSpec spec, Set<String> symbols) {
  const parameters = '(context, node, props, buildChild)';
  if (spec.props.isEmpty) {
    return '$parameters => ${spec.constructorReference}()';
  }
  final out = StringBuffer('$parameters => ${spec.constructorReference}(');
  for (final prop in spec.props.where((p) => !p.isNamed)) {
    out.write('${_argument(prop, symbols)}, ');
  }
  for (final prop in spec.props.where((p) => p.isNamed)) {
    out.write('${prop.dartName}: ${_argument(prop, symbols)}, ');
  }
  out.write(')');
  return out.toString();
}

/// The expression passed to the constructor for [prop].
///
/// A required property the agent left out never gets this far: a2ui_core
/// validates each message against the schema and rejects the component. What
/// is left is a property bound to a path that holds nothing yet, which falls
/// back to a neutral value until the data arrives, without a report, the way
/// a basic component shows an empty text. A property with a default falls
/// back to that default, so the Dart default applies; anything else stays
/// nullable.
String _argument(PropSpec prop, Set<String> symbols) {
  final key = dartString(prop.schemaName);

  String withFallback(String value, String fallback) {
    if (prop.isSchemaRequired) return '$value ?? $fallback';
    if (prop.defaultValueCode != null) {
      return '$value ?? ${defaultExpression(prop)}';
    }
    return value;
  }

  /// [value] when the property arrived, [orElse] otherwise.
  ///
  /// For the shapes whose reader cannot tell absent from empty: a list of
  /// children reads as empty either way, and an absent one has to leave the
  /// widget's own default in place.
  String whenPresent(String value) {
    final String orElse = prop.isSchemaRequired
        ? value
        : prop.defaultValueCode != null
        ? defaultExpression(prop)
        : 'null';
    if (orElse == value) return value;
    return 'props[$key] == null ? $orElse : $value';
  }

  switch (prop.kind) {
    case PropKind.string:
      return withFallback('props.string($key)', "''");
    case PropKind.integer:
      if (prop.isSchemaRequired) return '(props.number($key) ?? 0).toInt()';
      return withFallback('props.number($key)?.toInt()', '0');
    case PropKind.decimal:
    case PropKind.number:
      return withFallback('props.number($key)', '0');
    case PropKind.boolean:
      return withFallback('props.boolean($key)', 'false');
    case PropKind.enumeration:
      final type = prop.enumTypeName!;
      return withFallback(
        '$type.values.asNameMap()[props.string($key)]',
        '$type.values.first',
      );
    case PropKind.stringList:
      symbols.add('genUiAsStringList');
      return withFallback(
        'genUiAsStringList(props.value($key))',
        'const <String>[]',
      );
    case PropKind.integerList:
      symbols.add('genUiAsNumList');
      return withFallback(
        'genUiAsNumList(props.value($key))?.map((n) => n.toInt()).toList()',
        'const <int>[]',
      );
    case PropKind.decimalList:
      symbols.add('genUiAsNumList');
      return withFallback(
        'genUiAsNumList(props.value($key))?.map((n) => n.toDouble())'
            '.toList()',
        'const <double>[]',
      );
    case PropKind.numberList:
      symbols.add('genUiAsNumList');
      return withFallback('genUiAsNumList(props.value($key))', 'const <num>[]');
    case PropKind.enumerationList:
      // A name the enum does not declare is dropped rather than defaulted, as
      // on genui: the list is the agent's, and one bad entry should not
      // silently become a value the author never wrote.
      symbols.add('genUiAsStringList');
      final type = prop.enumTypeName!;
      return withFallback(
        'genUiAsStringList(props.value($key))?.map((name) => '
            '$type.values.asNameMap()[name]).nonNulls.toList()',
        'const <$type>[]',
      );
    case PropKind.map:
      return withFallback(
        mapExpression(prop, symbols, 'props.value($key)'),
        mapEmptyLiteral(prop),
      );
    case PropKind.data:
      // The reporter goes to the agent: a literal object was checked against
      // the schema when the message arrived, but one bound to a path was not,
      // and a required field missing there is the agent's to fix.
      symbols.addAll(['genUiAsObject', 'genUiMissingIn']);
      final decoder = prop.data!.decoderName;
      final orElse = prop.isSchemaRequired
          ? '$decoder(const <String, Object?>{})'
          : prop.defaultValueCode != null
          ? defaultExpression(prop)
          : 'null';
      return 'switch (genUiAsObject(props.value($key))) { '
          'final Map<String, Object?> json => '
          '$decoder(json, genUiMissingIn(context, node, $key)), '
          '_ => $orElse }';
    case PropKind.dataList:
      symbols.addAll(['genUiAsObjectList', 'genUiMissingIn']);
      return withFallback(
        'genUiAsObjectList(props.value($key))?.map((json) => '
            '${prop.data!.decoderName}(json, '
            'genUiMissingIn(context, node, $key))).toList()',
        'const <${prop.data!.className}>[]',
      );
    case PropKind.widget:
      if (prop.isSchemaRequired) symbols.add('SizedBox');
      final orElse = prop.isSchemaRequired
          ? 'const SizedBox.shrink()'
          : prop.defaultValueCode != null
          ? defaultExpression(prop)
          : 'null';
      return 'switch (props.child($key)) { '
          'final childNode? => buildChild(childNode), '
          'null => $orElse }';
    case PropKind.widgetList:
      // A static list and a template both arrive as nodes: a2ui_core expands
      // the template over its path, so the widget sees one child per entry.
      return whenPresent('props.children($key).map(buildChild).toList()');
    case PropKind.action:
      return withFallback('props.action($key)', '() {}');
    case PropKind.valueWriter:
      // Writable only when the agent bound the property to a path; a literal
      // has nowhere to go, the way a basic control with a literal value is
      // read-only. A nullable callback receives null then, so the widget can
      // show itself disabled.
      symbols.add('genUiWriter');
      final target = dartString(prop.writesProperty!);
      final encode = prop.writerValueKind == PropKind.enumeration
          ? ', encode: (value) => value.name'
          : '';
      final writer =
          'genUiWriter<${prop.writerTypeName}>(context, props, $target'
          '$encode)';
      return prop.isNullable ? writer : '$writer ?? (_) {}';
    case PropKind.checkResult:
      if (prop.checkShape == CheckResultShape.result) {
        symbols.add('GenUiCheckResult');
      }
      return switch (prop.checkShape!) {
        CheckResultShape.message => 'props.validationErrors.firstOrNull',
        CheckResultShape.isValid => 'props.isValid',
        CheckResultShape.result =>
          'GenUiCheckResult(isValid: props.isValid, '
              'message: props.validationErrors.firstOrNull)',
      };
  }
}

// --- Functions -----------------------------------------------------------

/// Emits the `final FunctionImplementation <name>GenUiFunction = ...;`
/// declaration for [spec].
///
/// a2ui_core resolves every argument before it calls the function, so the
/// body reads plain values out of `args`, through the same coercions a
/// `@GenUiData` field uses. The argument schema still allows a binding or a
/// call for each one, since that is what the agent writes in the message.
EmittedCode emitFunctionImplementation(FunctionSpec spec) {
  final symbols = <String>{
    'FunctionImplementation',
    'GenUiClientFunction',
    'A2uiReturnType',
    'S',
  };
  final String constructor = switch (spec.delivery) {
    FunctionDelivery.sync => 'GenUiClientFunction',
    FunctionDelivery.async => 'GenUiClientFunction.async',
    FunctionDelivery.streaming => 'GenUiClientFunction.streaming',
  };
  final String returnType = switch (spec.returns) {
    FunctionReturn.empty => 'void_',
    _ => spec.returns.constantName,
  };

  final out = StringBuffer()
    ..writeln('/// Generated catalog function for [${spec.dartName}].')
    ..writeln(
      'final FunctionImplementation ${spec.variableName} = $constructor(',
    )
    ..writeln('  name: ${dartString(spec.functionName)},')
    ..writeln('  description: ${dartWrappedString(spec.description)},')
    ..writeln('  argumentSchema: ${_argumentSchema(spec, symbols)},')
    ..writeln('  returnType: A2uiReturnType.$returnType,')
    ..writeln('  body: (args, context) {');

  if (spec.args.isEmpty) {
    out.writeln('    return ${spec.dartName}();');
  } else {
    symbols.add('GenUiMissingFieldReporter');
    out
      ..writeln('    final json = args;')
      // A function has no component to attribute a missing argument to, so
      // the fallback is taken silently, as it is on genui.
      ..writeln('    const GenUiMissingFieldReporter? onMissing = null;')
      ..writeln('    return ${spec.dartName}(');
    for (final arg in spec.args) {
      final value = decodeArgument(arg, symbols);
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
  symbols.add('GenUiSchemas');
  final out = StringBuffer('S.object(\n    properties: {\n');
  for (final arg in spec.args) {
    out.writeln(
      '      ${dartString(arg.schemaName)}: '
      '${propertySchemaA2ui(arg, symbols)},',
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
