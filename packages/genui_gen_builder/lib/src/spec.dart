/// Intermediate representation of an annotated widget.
///
/// The generator first analyses the annotated class into a [WidgetSpec]
/// (see `generator.dart`) and then turns that spec into Dart source (see
/// `emitter.dart`). Keeping the two steps apart makes the emitted shape easy
/// to reason about and test.
library;

/// How a constructor parameter is exposed in the generated catalog item.
enum PropKind {
  /// `String` / `String?` → `A2uiSchemas.stringReference`.
  string,

  /// `int` / `int?` → `A2uiSchemas.numberReference`, resolved with `toInt()`.
  integer,

  /// `double` / `double?` → `A2uiSchemas.numberReference`, resolved with
  /// `toDouble()`.
  decimal,

  /// `num` / `num?` → `A2uiSchemas.numberReference`.
  number,

  /// `bool` / `bool?` → `A2uiSchemas.booleanReference`.
  boolean,

  /// A Dart `enum` → `A2uiSchemas.stringReference(enumValues: ...)`.
  enumeration,

  /// `List<String>` (+nullable) → `A2uiSchemas.stringArrayReference`.
  stringList,

  /// `List<int>` (+nullable) → `A2uiSchemas.listOrReference(items:
  /// S.number())`, each entry resolved with `toInt()`.
  integerList,

  /// `List<double>` (+nullable) → same schema, resolved with `toDouble()`.
  decimalList,

  /// `List<num>` (+nullable) → same schema, resolved as-is.
  numberList,

  /// `List<E>` where `E` is a Dart `enum` (+nullable) →
  /// `A2uiSchemas.listOrReference(items: S.string(enumValues: ...))`.
  enumerationList,

  /// A class annotated with `@GenUiData` (+nullable) → the generated
  /// `ObjectSchema` for that class.
  data,

  /// `List<T>` where `T` is annotated with `@GenUiData` (+nullable) →
  /// `S.list(items: <T schema>)`.
  dataList,

  /// `Widget` / `Widget?` → `A2uiSchemas.componentReference`.
  widget,

  /// `List<Widget>` (+nullable) → `S.list(items: componentReference())`.
  widgetList,

  /// `VoidCallback` / `void Function()` (+nullable) → `A2uiSchemas.action`.
  action,
}

extension PropKindX on PropKind {
  /// Whether the value is resolved through `GenUiBindings` (i.e. it supports
  /// genui's literal / `{"path": ...}` / `{"call": ...}` forms).
  bool get isBound => switch (this) {
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
    PropKind.enumerationList ||
    PropKind.data ||
    PropKind.dataList => true,
    PropKind.widget || PropKind.widgetList || PropKind.action => false,
  };

  /// Whether the value is a `@GenUiData` object or a list of them.
  bool get isData => this == PropKind.data || this == PropKind.dataList;

  /// Whether the value is a child component reference built through
  /// `ctx.buildChild`.
  bool get isChild => this == PropKind.widget || this == PropKind.widgetList;
}

/// One constructor parameter that ends up in the generated schema.
final class PropSpec {
  PropSpec({
    required this.dartName,
    required this.schemaName,
    required this.kind,
    required this.isNullable,
    required this.isRequiredInConstructor,
    required this.isNamed,
    required this.defaultValueCode,
    required this.description,
    this.enumTypeName,
    this.enumValues = const [],
    this.eventName,
    this.data,
  });

  /// The constructor parameter name.
  final String dartName;

  /// The property name in the JSON schema and component data.
  ///
  /// Defaults to [dartName]; `@GenUiProp(name: ...)` overrides it.
  final String schemaName;

  /// How the parameter is mapped.
  final PropKind kind;

  /// Whether the Dart type is nullable.
  final bool isNullable;

  /// Whether the parameter is `required` (named) or a required positional.
  final bool isRequiredInConstructor;

  /// Whether the parameter is named (as opposed to positional).
  final bool isNamed;

  /// Source of the default value, or `null` when there is none.
  final String? defaultValueCode;

  /// Description fed to the LLM, or `null` when none could be found.
  final String? description;

  /// For [PropKind.enumeration]: the enum type name as visible from the
  /// annotated library.
  final String? enumTypeName;

  /// For [PropKind.enumeration]: the enum constant names, in declaration
  /// order.
  final List<String> enumValues;

  /// For [PropKind.action]: the event name used in the generated example.
  final String? eventName;

  /// For [PropKind.data] and [PropKind.dataList]: the analysed data class.
  final DataSpec? data;

  /// Whether the property is listed under `required` in the schema.
  ///
  /// A property is required iff the parameter is required in the constructor,
  /// has no default value and is non-nullable. When such a value is missing
  /// at runtime the generated builder substitutes a fallback and reports the
  /// problem through `ctx.reportError`.
  bool get isSchemaRequired =>
      isRequiredInConstructor && defaultValueCode == null && !isNullable;
}

/// A fully analysed `@GenUiData` class.
///
/// A data class contributes two declarations to the generated part: the
/// `ObjectSchema` describing the JSON the model must emit, and the decoder
/// that turns that JSON back into an instance.
final class DataSpec {
  DataSpec({
    required this.className,
    required this.constructorName,
    required this.description,
    required this.fields,
    required this.libraryUri,
  });

  /// The annotated class name.
  final String className;

  /// URI of the library that declares the class, used to tell two classes
  /// with colliding generated names apart in diagnostics.
  final String libraryUri;

  /// The constructor to call; empty for the unnamed constructor.
  final String constructorName;

  /// Description written into the generated schema, or `null` when none was
  /// given and the class has no doc comment.
  final String? description;

  /// Constructor parameters in declaration order.
  final List<PropSpec> fields;

  /// Name of the generated schema variable, e.g. `rowGenUiSchema`.
  String get schemaVariableName => '${lowerCamel(className)}GenUiSchema';

  /// Name of the generated decoder function, e.g. `rowFromGenUiJson`.
  String get decoderName => '${lowerCamel(className)}FromGenUiJson';

  /// The Dart expression used to invoke the chosen constructor.
  String get constructorReference =>
      constructorName.isEmpty ? className : '$className.$constructorName';

  Iterable<PropSpec> get requiredFields =>
      fields.where((f) => f.isSchemaRequired);
}

/// A fully analysed `@GenUiWidget` class.
final class WidgetSpec {
  WidgetSpec({
    required this.className,
    required this.constructorName,
    required this.catalogName,
    required this.description,
    required this.isImplicitlyFlexible,
    required this.props,
  });

  /// The annotated class name.
  final String className;

  /// The constructor to call; empty for the unnamed constructor.
  final String constructorName;

  /// The `CatalogItem.name` (the `component` discriminator in JSON).
  final String catalogName;

  /// The widget description fed to the LLM.
  final String description;

  /// Forwarded to `CatalogItem.isImplicitlyFlexible`.
  final bool isImplicitlyFlexible;

  /// Properties in constructor declaration order.
  final List<PropSpec> props;

  /// Name of the generated top-level variable, e.g. `productCardCatalogItem`.
  String get variableName => '${lowerCamel(className)}CatalogItem';

  /// The Dart expression used to invoke the chosen constructor.
  String get constructorReference =>
      constructorName.isEmpty ? className : '$className.$constructorName';

  Iterable<PropSpec> get boundProps => props.where((p) => p.kind.isBound);

  Iterable<PropSpec> get childProps => props.where((p) => p.kind.isChild);

  Iterable<PropSpec> get requiredProps =>
      props.where((p) => p.isSchemaRequired);
}

/// Converts `ProductCard` → `productCard`, `HTTPCard` → `httpCard` and
/// `_Private` → `_private`.
String lowerCamel(String name) {
  final underscore = name.startsWith('_') ? '_' : '';
  final body = name.substring(underscore.length);
  if (body.isEmpty) return name;
  var upperRun = 0;
  while (upperRun < body.length && _isUpper(body[upperRun])) {
    upperRun++;
  }
  if (upperRun == 0) return name;
  // Keep the last capital of a run if it starts the next word (HTTPCard).
  final lowerCount = (upperRun > 1 && upperRun < body.length)
      ? upperRun - 1
      : upperRun;
  return underscore +
      body.substring(0, lowerCount).toLowerCase() +
      body.substring(lowerCount);
}

bool _isUpper(String char) =>
    char.toUpperCase() == char && char.toLowerCase() != char;
