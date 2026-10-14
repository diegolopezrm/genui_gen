/// Test harness for the a2ui_flutter renderer.
///
/// Replaces the genui flavour of the `package:genui_gen` stub with one built
/// on a2ui_flutter: the same annotations, declared next to the marker the
/// builder reads, and the a2ui_flutter types the generated code names instead
/// of genui's.
library;

import 'harness.dart';

/// The annotation classes of the genui stub, which both flavours share.
final String _annotations = () {
  final String genui = stubAssets['genui_gen|lib/genui_gen.dart']!;
  final int start = genui.indexOf('class GenUiWidget');
  final int end = genui.indexOf('enum ClientFunctionReturnType');
  return genui
      .substring(start, end)
      // The genui flavour's helpers for checks, which the shared slice
      // happens to include; the a2ui flavour declares its own below.
      .replaceAll(RegExp(r'class GenUiChecks \{[\s\S]*?\n\}\n'), '');
}();

/// `package:genui_gen` as built on a2ui_flutter.
final String a2uiGenUiGenStub =
    '''
library;

import 'package:flutter/widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

export 'package:json_schema_builder/json_schema_builder.dart'
    show ObjectSchema, S, Schema;

const bool genUiGenTargetsA2uiFlutter = true;

$_annotations

class ComponentProps {
  Object? operator [](String key) => null;
  Object? value(String key) => null;
  String? string(String key) => null;
  double? number(String key) => null;
  bool? boolean(String key) => null;
  Future<void> Function()? action(String key) => null;
  Object? child(String key) => null;
  List<Object> children(String key) => const [];
  bool get isValid => true;
  List<String> get validationErrors => const [];
}

class ComponentImplementation {
  const ComponentImplementation({
    required this.name,
    required this.schema,
    required this.builder,
  });
  final String name;
  final Schema schema;
  final Widget Function(
    BuildContext context,
    Object node,
    ComponentProps props,
    Widget Function(Object child) buildChild,
  ) builder;
}

class GenUiComponent extends ComponentImplementation {
  const GenUiComponent({
    required super.name,
    required super.schema,
    required super.builder,
    this.examples = const [],
  });
  final List<String> examples;
}

String? genUiExampleInstructions(Iterable<ComponentImplementation> components) =>
    null;

class CatalogImplementation {
  CatalogImplementation({
    required String id,
    required List<ComponentImplementation> components,
    List<FunctionImplementation> functions = const [],
  });
}

abstract class FunctionImplementation {}

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

class GenUiClientFunction extends FunctionImplementation {
  GenUiClientFunction({
    required String name,
    required String description,
    required Schema argumentSchema,
    A2uiReturnType returnType = A2uiReturnType.any,
    required Object? Function(Map<String, Object?> args, Object? context) body,
  });
  GenUiClientFunction.async({
    required String name,
    required String description,
    required Schema argumentSchema,
    A2uiReturnType returnType = A2uiReturnType.any,
    required Object? Function(Map<String, Object?> args, Object? context) body,
  });
  GenUiClientFunction.streaming({
    required String name,
    required String description,
    required Schema argumentSchema,
    A2uiReturnType returnType = A2uiReturnType.any,
    required Object? Function(Map<String, Object?> args, Object? context) body,
  });
}

abstract final class GenUiSchemas {
  static Schema component({
    required String description,
    Map<String, Schema> properties = const {},
    List<String> required = const [],
  }) => const Schema();
  static Schema string({String? description, List<String>? enumValues}) =>
      const Schema();
  static Schema number({String? description}) => const Schema();
  static Schema boolean({String? description}) => const Schema();
  static Schema stringList({String? description}) => const Schema();
  static Schema list({required Schema items, String? description}) =>
      const Schema();
  static Schema object({required Schema literal, String? description}) =>
      const Schema();
  static Schema componentId({String? description}) => const Schema();
  static Schema componentIdList({String? description}) => const Schema();
  static Schema childList({String? description}) => const Schema();
  static Schema action({String? description}) => const Schema();
  static Schema checks() => const Schema();
}

typedef GenUiMissingFieldReporter = void Function(String field);

void Function(T)? genUiWriter<T>(
  BuildContext context,
  ComponentProps props,
  String property, {
  Object? Function(T value)? encode,
}) => null;

GenUiMissingFieldReporter genUiMissingIn(
  BuildContext context,
  Object node,
  String property,
) => (field) {};

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
''';

/// The imports an annotated file on a2ui_flutter starts with.
const a2uiImports = '''
import 'package:flutter/widgets.dart';
import 'package:genui_gen/genui_gen.dart';
''';

/// Runs the builder on [body] against the a2ui_flutter flavour of
/// `package:genui_gen`, and returns the [normalize]d part.
Future<String> generateA2ui(String body, {String? imports}) async => normalize(
  await generateRaw(
    body,
    imports: imports ?? a2uiImports,
    extraAssets: {'genui_gen|lib/genui_gen.dart': a2uiGenUiGenStub},
  ),
);
