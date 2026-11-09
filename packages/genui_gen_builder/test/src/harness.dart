/// Test harness: runs the builder against in-memory sources.
///
/// The real `package:flutter`, `package:a2ui_core`, `package:a2ui_flutter`,
/// `package:genui_gen` and `package:json_schema_builder` are replaced by
/// minimal stubs declaring only the symbols the generator looks at, so the
/// suite runs with plain `dart test` and no Flutter SDK.
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:genui_gen_builder/builder.dart';
import 'package:test/test.dart';

/// Stub sources keyed by `package|path`.
const stubAssets = <String, String>{
  'flutter|lib/widgets.dart': '''
library;

class Key {
  const Key(String value);
}

abstract class Widget {
  const Widget({Key? key});
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
}

class SizedBox extends Widget {
  const SizedBox({super.key});
  const SizedBox.shrink({super.key});
}

class BuildContext {}

typedef VoidCallback = void Function();

typedef ValueChanged<T> = void Function(T value);
''',
  'json_schema_builder|lib/json_schema_builder.dart': '''
library;

class Schema {
  const Schema();
  factory Schema.object({
    String? description,
    Map<String, Schema>? properties,
    List<String>? required,
  }) = ObjectSchema;
  factory Schema.list({String? description, Schema? items}) => const Schema();
  factory Schema.fromMap(Map<String, Object?> value) => const Schema();
  factory Schema.string({String? description, List<Object?>? enumValues}) =>
      const Schema();
  factory Schema.number({String? description}) => const Schema();
  factory Schema.integer({String? description}) => const Schema();
  factory Schema.boolean({String? description}) => const Schema();
  factory Schema.combined({
    String? description,
    List<Object?>? oneOf,
    List<Object?>? anyOf,
  }) => const Schema();
  factory Schema.any() => const Schema();
  const Schema._();
  Map<String, Object?> get value => const {};
}

class ObjectSchema extends Schema {
  const ObjectSchema({
    String? description,
    Map<String, Schema>? properties,
    List<String>? required,
  }) : super._();
}

typedef S = Schema;
''',
  'a2ui_core|lib/a2ui_core.dart': '''
library;

import 'package:json_schema_builder/json_schema_builder.dart';

abstract final class CommonSchemas {
  static const Schema dataBinding = Schema();
  static const Schema functionCall = Schema();
  static const Schema dynamicString = Schema();
  static const Schema dynamicNumber = Schema();
  static const Schema dynamicBoolean = Schema();
  static const Schema dynamicStringList = Schema();
  static const Schema componentId = Schema();
  static const Schema childList = Schema();
  static const Schema action = Schema();
  static const Schema checkRule = Schema();
}

enum A2uiReturnType {
  string,
  number,
  boolean,
  array,
  object,
  validationResult,
  any,
  void_,
}

class DataContext {}

typedef NodeAction = Future<void> Function();

abstract class FunctionImplementation {
  const FunctionImplementation();
}
''',
  'a2ui_flutter|lib/a2ui_flutter.dart': '''
library;

import 'package:json_schema_builder/json_schema_builder.dart';

class ComponentNode {}

class ComponentProps {
  Object? value(String key) => null;
  ComponentNode? child(String key) => null;
  List<ComponentNode> children(String key) => const [];
  Object? action(String key) => null;
}

class ComponentImplementation {
  const ComponentImplementation({
    required this.name,
    required this.schema,
    required this.builder,
  });
  final String name;
  final Schema schema;
  final Object Function(
    Object context,
    ComponentNode node,
    ComponentProps props,
    Object Function(ComponentNode child) buildChild,
  ) builder;
}

class CatalogImplementation {
  CatalogImplementation({
    required this.id,
    required List<ComponentImplementation> components,
    List<Object> functions = const [],
  });
  final String id;
}
''',
  'genui_gen|lib/genui_gen.dart': '''
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/widgets.dart';

export 'package:a2ui_core/a2ui_core.dart'
    show A2uiReturnType, CommonSchemas, FunctionImplementation;
export 'package:a2ui_flutter/a2ui_flutter.dart'
    show CatalogImplementation, ComponentImplementation;
export 'package:json_schema_builder/json_schema_builder.dart'
    show ObjectSchema, S, Schema;

class CatalogItem extends ComponentImplementation {
  const CatalogItem({
    required super.name,
    required super.schema,
    required super.builder,
    this.exampleData = const [],
  });
  final List<String Function()> exampleData;
}

class GenUiWidget {
  const GenUiWidget({
    this.name,
    required this.description,
    this.constructor,
    this.isImplicitlyFlexible = false,
  });
  final String? name;
  final String description;
  final String? constructor;
  final bool isImplicitlyFlexible;
}

class GenUiData {
  const GenUiData({this.description, this.constructor});
  final String? description;
  final String? constructor;
}

class GenUiProp {
  const GenUiProp({
    this.description,
    this.name,
    this.ignore = false,
    this.template = false,
  });
  final String? description;
  final String? name;
  final bool ignore;
  final bool template;
}

class GenUiAction {
  const GenUiAction({this.eventName, this.description});
  final String? eventName;
  final String? description;
}

class GenUiChecked {
  const GenUiChecked();
}

class GenUiCheckResult {
  const GenUiCheckResult({required this.isValid, required this.message});
  factory GenUiCheckResult.of(ComponentProps props) =>
      const GenUiCheckResult(isValid: true, message: null);
  final bool isValid;
  final String? message;
}

class GenUiWrites {
  const GenUiWrites(this.property);
  final String property;
}

class GenUiFunction {
  const GenUiFunction({required this.description, this.name});
  final String description;
  final String? name;
}

class GenUiClientFunction extends FunctionImplementation {
  GenUiClientFunction({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = A2uiReturnType.any,
    required this.body,
  });
  GenUiClientFunction.async({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = A2uiReturnType.any,
    required this.body,
  });
  GenUiClientFunction.streaming({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = A2uiReturnType.any,
    required this.body,
  });
  final String name;
  final String description;
  final Schema argumentSchema;
  final A2uiReturnType returnType;
  final Object? Function(Map<String, Object?> args, DataContext context) body;
}

typedef GenUiDecoder<T> = T Function(Map<String, Object?> json);

typedef GenUiMissingFieldReporter = void Function(String field);

void Function()? genUiActionHandler(Object? action) => null;

Object? genUiWrittenValue(
  ComponentNode node,
  ComponentProps props,
  String property,
) => null;

void Function(T) genUiValueWriter<T>(
  ComponentNode node,
  ComponentProps props,
  String property, {
  Object? Function(T value)? encode,
}) => (T value) {};

void genUiReportMissing(
  ComponentNode node,
  String component,
  String property,
) {}

String? genUiAsString(Object? value) => null;
num? genUiAsNum(Object? value) => null;
bool? genUiAsBool(Object? value) => null;
List<String>? genUiAsStringList(Object? value) => null;
List<num>? genUiAsNumList(Object? value) => null;
Map<String, Object?>? genUiAsObject(Object? value) => null;
List<Map<String, Object?>>? genUiAsObjectList(Object? value) => null;
Map<String, String>? genUiAsStringMap(Object? value) => null;
Map<String, num>? genUiAsNumMap(Object? value) => null;
Map<String, bool>? genUiAsBoolMap(Object? value) => null;

T genUiMissingField<T>(
  GenUiMissingFieldReporter? onMissing,
  String field,
  T fallback,
) => fallback;

GenUiMissingFieldReporter? genUiNestedField(
  GenUiMissingFieldReporter? onMissing,
  String field,
) => onMissing;
''',
};

/// The default imports prepended to every widget source by [generate].
const defaultImports = '''
import 'package:flutter/widgets.dart';
import 'package:genui_gen/genui_gen.dart';
''';

/// Thrown by [generate] when the build fails; [errors] holds the build log
/// error messages (including `InvalidGenerationSourceError` text).
class GenerationFailure implements Exception {
  GenerationFailure(this.errors);

  final List<String> errors;

  /// All error messages joined, for `contains` matchers.
  String get message => errors.join('\n');

  @override
  String toString() => 'GenerationFailure:\n$message';
}

/// Runs the builder on `package:a/widget.dart` containing [body] and returns
/// the generated `widget.genui.dart` content, [normalize]d so that tests can
/// match fragments regardless of how `dart format` wrapped the code.
///
/// [imports] replaces [defaultImports] when given; the `part` directive is
/// always added. [extraAssets] adds further in-memory sources.
Future<String> generate(
  String body, {
  String? imports,
  Map<String, String> extraAssets = const {},
}) async => normalize(
  await generateRaw(body, imports: imports, extraAssets: extraAssets),
);

/// Collapses whitespace and removes the trailing commas `dart format` adds
/// when it wraps an argument list, so `contains` matchers can use compact
/// single-line fragments.
String normalize(String code) => code
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAllMapped(RegExp(r'([(\[{]) '), (m) => m[1]!)
    .replaceAllMapped(RegExp(r' ([)\]}])'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r',([)\]}])'), (m) => m[1]!)
    // Collapse indented JSON (`"key": value`, `}, {`) to its compact form.
    .replaceAll('": ', '":')
    .replaceAll(', "', ',"')
    .replaceAll(', {', ',{');

/// Joins the adjacent string literals `dart format` leaves behind when it
/// wraps a long description.
///
/// Opt-in rather than part of [normalize], because whether a description is
/// split at all is itself something `widget_test.dart` checks.
String joinLiterals(String code) => code.replaceAll("' '", '');

/// Like [generate] but returns the file exactly as written by the builder.
/// Runs the builder and returns the warnings it logged.
Future<List<String>> generateWarnings(
  String body, {
  String? imports,
  Map<String, String> extraAssets = const {},
}) async {
  final warnings = <String>[];
  await generateRaw(
    body,
    imports: imports,
    extraAssets: extraAssets,
    warnings: warnings,
  );
  return warnings;
}

Future<String> generateRaw(
  String body, {
  String? imports,
  Map<String, String> extraAssets = const {},
  List<String>? warnings,
}) async {
  final source =
      '${imports ?? defaultImports}\n'
      "part 'widget.genui.dart';\n\n"
      '$body';
  final errors = <String>[];
  final result = await testBuilder(
    genUiGenBuilder(const BuilderOptions({})),
    {...stubAssets, ...extraAssets, 'a|lib/widget.dart': source},
    rootPackage: 'a',
    onLog: (record) {
      if (record.level.value >= 1000) {
        errors.add('${record.message}${_errorOf(record.error)}');
      } else if (record.level.value >= 900) {
        warnings?.add(record.message);
      }
    },
  );
  if (!result.succeeded) {
    throw GenerationFailure(errors.isEmpty ? result.errors.toList() : errors);
  }
  final outputId = AssetId('a', 'lib/widget.genui.dart');
  final reader = result.readerWriter.testing;
  final generatedId = reader.exists(outputId)
      ? outputId
      : AssetId('a', '.dart_tool/build/generated/a/lib/widget.genui.dart');
  return reader.readString(generatedId);
}

String _errorOf(Object? error) => error == null ? '' : '\n$error';

/// Matcher for a [GenerationFailure] whose message contains every fragment.
Matcher failsWith(List<String> fragments) => throwsA(
  isA<GenerationFailure>().having(
    (f) => f.message,
    'message',
    allOf([for (final fragment in fragments) contains(fragment)]),
  ),
);
