/// Test harness: runs the builder against in-memory sources.
///
/// The real `package:flutter`, `package:genui`, `package:genui_gen` and
/// `package:json_schema_builder` are replaced by minimal stubs declaring
/// only the symbols the generator looks at, so the suite runs with plain
/// `dart test` and no Flutter SDK.
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
  factory Schema.string({String? description, List<Object?>? enumValues}) =>
      const Schema();
  factory Schema.number({String? description}) => const Schema();
  factory Schema.integer({String? description}) => const Schema();
  factory Schema.boolean({String? description}) => const Schema();
  factory Schema.combined({String? description, List<Object?>? oneOf}) =>
      const Schema();
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
  'genui|lib/genui.dart': '''
library;

import 'package:json_schema_builder/json_schema_builder.dart';

typedef JsonMap = Map<String, Object?>;

class DataContext {}

class CatalogItemContext {
  final Object data;
  final DataContext dataContext;
  final Object Function(String id, [DataContext? ctx]) buildChild;
  final void Function(Object error, StackTrace? stack) reportError;
  CatalogItemContext(
    this.data,
    this.dataContext,
    this.buildChild,
    this.reportError,
  );
}

class CatalogItem {
  const CatalogItem({
    required this.name,
    required this.dataSchema,
    required this.widgetBuilder,
    this.exampleData = const [],
    this.isImplicitlyFlexible = false,
  });
  final String name;
  final Schema dataSchema;
  final Object Function(CatalogItemContext ctx) widgetBuilder;
  final List<String Function()> exampleData;
  final bool isImplicitlyFlexible;
}

abstract final class A2uiSchemas {
  static Schema stringReference({
    String? description,
    List<String>? enumValues,
  }) => const Schema();
  static Schema numberReference({String? description}) => const Schema();
  static Schema booleanReference({String? description}) => const Schema();
  static Schema stringArrayReference({String? description}) =>
      const Schema();
  static Schema componentReference({String? description}) => const Schema();
  static Schema action({String? description}) => const Schema();
  static Schema dataBindingSchema({String? description}) => const Schema();
  static Schema functionCall() => const Schema();
  static Schema listOrReference({
    required Schema items,
    String? description,
  }) => const Schema();
}
''',
  'genui_gen|lib/genui_gen.dart': '''
library;

export 'package:json_schema_builder/json_schema_builder.dart'
    show ObjectSchema, S, Schema;

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
  const GenUiProp({this.description, this.name, this.ignore = false});
  final String? description;
  final String? name;
  final bool ignore;
}

class GenUiAction {
  const GenUiAction({this.eventName, this.description});
  final String? eventName;
  final String? description;
}

class GenUiBindings {
  const GenUiBindings({
    required this.dataContext,
    required this.bindings,
    required this.builder,
  });
  final Object dataContext;
  final Map<String, GenUiBinding> bindings;
  final Object Function(Object context, GenUiValues values) builder;
}

sealed class GenUiBinding {
  const factory GenUiBinding.string(Object? raw) = _Binding;
  const factory GenUiBinding.number(Object? raw) = _Binding;
  const factory GenUiBinding.bool(Object? raw) = _Binding;
  const factory GenUiBinding.stringList(Object? raw) = _Binding;
  const factory GenUiBinding.object(Object? raw) = _Binding;
  const factory GenUiBinding.objectList(Object? raw) = _Binding;
}

class _Binding implements GenUiBinding {
  const _Binding(this.raw);
  final Object? raw;
}

class GenUiValues {
  String? string(String key) => null;
  num? number(String key) => null;
  bool? boolean(String key) => null;
  List<String>? stringList(String key) => null;
  Map<String, Object?>? object(String key) => null;
  List<Map<String, Object?>>? objectList(String key) => null;
}

typedef GenUiDecoder<T> = T Function(Map<String, Object?> json);

typedef GenUiMissingFieldReporter = void Function(String field);

void Function()? genUiActionHandler(Object ctx, Object? actionData) => null;

void genUiReportMissing(Object ctx, String component, String property) {}

String? genUiAsString(Object? value) => null;
num? genUiAsNum(Object? value) => null;
bool? genUiAsBool(Object? value) => null;
List<String>? genUiAsStringList(Object? value) => null;
Map<String, Object?>? genUiAsObject(Object? value) => null;
List<Map<String, Object?>>? genUiAsObjectList(Object? value) => null;

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
import 'package:genui/genui.dart';
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
