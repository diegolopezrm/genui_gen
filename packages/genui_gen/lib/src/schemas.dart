import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The schemas generated components describe their properties with.
///
/// a2ui_core resolves a component against its schema before the builder runs,
/// and what it hands the builder depends on the shape it finds: a property
/// marked as a dynamic value arrives as a binding, a `ComponentId` as a child
/// node, an `Action` as a closure. These helpers build those shapes from
/// [CommonSchemas], with the description of the property in place of the
/// shared one, so that the agent reads what the property means here.
///
/// Generated code calls them; a hand-written `ComponentImplementation` can as
/// well.
abstract final class GenUiSchemas {
  /// The description the basic catalog gives `weight`.
  static const String _weightDescription =
      'The relative weight of this component within a Row or Column. This is '
      "similar to the CSS 'flex-grow' property. Note: this may ONLY be set "
      'when the component is a direct descendant of a Row or Column.';

  /// A component: [properties], plus the ones every component of the basic
  /// catalog takes.
  ///
  /// `accessibility` carries the label and description a renderer gives
  /// assistive technologies, and `weight` the share of a basic `Row` or
  /// `Column` the component takes. With both, a generated component sits in a
  /// basic layout like any basic component.
  ///
  /// Any other property is rejected when the message arrives, as it is on a
  /// basic component, so the agent cannot invent one the widget does not take.
  static Schema component({
    required String description,
    Map<String, Schema> properties = const {},
    List<String> required = const [],
  }) => Schema.object(
    description: description,
    properties: {
      ...properties,
      'accessibility': CommonSchemas.accessibilityAttributes,
      'weight': Schema.number(description: _weightDescription),
    },
    required: required.isEmpty ? null : required,
    additionalProperties: false,
  );

  /// A string the agent may write out, bind to a path or compute.
  ///
  /// With [enumValues], the literal is limited to those names. The schema then
  /// cannot be the shared `DynamicString`, which allows any string, so it is
  /// spelled out: the literal, a binding or a call.
  static Schema string({String? description, List<String>? enumValues}) {
    if (enumValues == null) {
      return _describe(CommonSchemas.dynamicString, description);
    }
    return _dynamic(
      Schema.string(enumValues: enumValues),
      description: description,
    );
  }

  /// A number the agent may write out, bind to a path or compute.
  static Schema number({String? description}) =>
      _describe(CommonSchemas.dynamicNumber, description);

  /// A boolean the agent may write out, bind to a path or compute.
  static Schema boolean({String? description}) =>
      _describe(CommonSchemas.dynamicBoolean, description);

  /// A list of strings the agent may write out, bind to a path or compute.
  static Schema stringList({String? description}) =>
      _describe(CommonSchemas.dynamicStringList, description);

  /// A list of [items] the agent may write out, bind to a path or compute.
  static Schema list({required Schema items, String? description}) =>
      _dynamic(Schema.list(items: items), description: description);

  /// An object shaped like [literal] that the agent may write out, bind to a
  /// path or compute.
  static Schema object({required Schema literal, String? description}) =>
      _dynamic(literal, description: description);

  /// A single child, by component id.
  static Schema componentId({String? description}) =>
      _describe(CommonSchemas.componentId, description);

  /// A list of children, by component id.
  static Schema componentIdList({String? description}) =>
      Schema.list(description: description, items: CommonSchemas.componentId);

  /// A list of children, by component id or as a template repeated over a
  /// path: the shared `ChildList`.
  static Schema childList({String? description}) =>
      _describe(CommonSchemas.childList, description);

  /// An event the component sends, or a function it calls, when the user
  /// acts on it.
  static Schema action({String? description}) =>
      _describe(CommonSchemas.action, description);

  /// The validation rules the agent attaches to a component, which a2ui_core
  /// evaluates into its `isValid` and `validationErrors`.
  static Schema checks() => Schema.list(
    description:
        'Validation rules for this component. Each one is a condition and '
        'the message shown while the condition is false.',
    items: CommonSchemas.checkRule,
  );

  /// [schema] with [description] in place of its own.
  ///
  /// Everything else is kept, including the marker that names the shared type
  /// the schema mirrors, which is what a2ui_core reads it by and what the
  /// catalog document turns back into a `$ref`.
  static Schema _describe(Schema schema, String? description) {
    if (description == null) return schema;
    return Schema.fromMap({...schema.value, 'description': description});
  }

  /// [literal], a data binding or a function call.
  ///
  /// a2ui_core reads an unmarked schema offering a data binding as a dynamic
  /// value, so a property shaped like this arrives in the builder as a binding
  /// whatever its literal is.
  static Schema _dynamic(Schema literal, {String? description}) =>
      Schema.combined(
        description: description,
        anyOf: [literal, CommonSchemas.dataBinding, CommonSchemas.functionCall],
      );
}
