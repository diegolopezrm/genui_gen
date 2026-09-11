import 'package:meta/meta_meta.dart';

/// Marks a widget class as a GenUI catalog component.
///
/// The `genui_gen_builder` package reads the annotated class's constructor
/// (the unnamed one by default, or [constructor] when set) and derives a
/// `CatalogItem` from it: the JSON schema comes from the parameter types, the
/// widget builder resolves every property against the surface's data model,
/// and a few-shot example is emitted from the required properties.
///
/// ```dart
/// @GenUiWidget(description: 'A product card with price and image.')
/// class ProductCard extends StatelessWidget {
///   const ProductCard({
///     super.key,
///     required this.title,
///     required this.price,
///     this.imageUrl,
///     this.onTap,
///   });
///
///   /// Product name.
///   final String title;
///
///   /// Price in USD.
///   final double price;
///
///   /// Optional image URL.
///   final String? imageUrl;
///
///   /// Fired when the card is tapped.
///   final VoidCallback? onTap;
///   // ...
/// }
/// ```
///
/// The generated part exposes `productCardCatalogItem`, ready to be added to a
/// genui `Catalog`.
@Target({TargetKind.classType})
class GenUiWidget {
  /// Creates a [GenUiWidget] annotation.
  ///
  /// [description] is required on purpose: it is the text the LLM reads to
  /// decide when to use this component, and a component without a description
  /// is rarely used correctly.
  const GenUiWidget({
    this.name,
    required this.description,
    this.constructor,
    this.isImplicitlyFlexible = false,
  });

  /// The component name used in the A2UI JSON (`"component": "<name>"`).
  ///
  /// Defaults to the annotated class name.
  final String? name;

  /// A description of the component, fed to the LLM as the schema description.
  final String description;

  /// The named constructor to derive the schema from.
  ///
  /// When `null` the unnamed constructor is used.
  final String? constructor;

  /// Whether the component should be implicitly flexible when placed inside a
  /// flex container such as the core `Row` or `Column`.
  ///
  /// Forwarded verbatim to `CatalogItem.isImplicitlyFlexible`. Enable it for
  /// widgets that require bounded constraints (lists, text fields, ...).
  final bool isImplicitlyFlexible;
}

/// Per-parameter overrides for a [GenUiWidget] constructor parameter.
///
/// The annotation is optional. Without it, the schema property takes the
/// parameter name and its description comes from the parameter's doc comment
/// (or, failing that, the corresponding field's doc comment). It may be placed
/// on the constructor parameter or, for `this.x` parameters, on the field.
///
/// ```dart
/// const Panel({
///   @GenUiProp(description: 'Title shown in the header.') required this.title,
///   @GenUiProp(ignore: true) this.elevation = 2,
/// });
/// ```
@Target({TargetKind.parameter, TargetKind.field})
class GenUiProp {
  /// Creates a [GenUiProp] annotation.
  const GenUiProp({this.description, this.name, this.ignore = false});

  /// The description of the schema property.
  ///
  /// Takes precedence over the parameter's and the field's doc comments.
  final String? description;

  /// The schema property name.
  ///
  /// Defaults to the Dart parameter name.
  final String? name;

  /// Whether to exclude the parameter from the schema entirely.
  ///
  /// An ignored parameter must be optional or have a default value, because
  /// the generated builder never passes it.
  final bool ignore;
}

/// Marks a `void Function()` / `VoidCallback` parameter as a user action.
///
/// The annotation is optional: every `VoidCallback` parameter is already
/// treated as an action. Use it to override the event name or the description
/// the LLM sees. It may be placed on the constructor parameter or, for
/// `this.x` parameters, on the field.
///
/// ```dart
/// const ProductCard({
///   @GenUiAction(eventName: 'product_selected') this.onTap,
/// });
/// ```
@Target({TargetKind.parameter, TargetKind.field})
class GenUiAction {
  /// Creates a [GenUiAction] annotation.
  const GenUiAction({this.eventName, this.description});

  /// The name of the `UserActionEvent` dispatched when the callback fires, as
  /// used in the generated example (`{"event": {"name": "<eventName>"}}`).
  ///
  /// Defaults to the parameter name (e.g. `onTap`). At runtime the event name
  /// always comes from the A2UI action data produced by the model; this value
  /// only seeds the example.
  final String? eventName;

  /// The description of the action property in the schema.
  ///
  /// Takes precedence over the parameter's and the field's doc comments.
  final String? description;
}

/// Marks a plain Dart class as a data shape an annotated widget may receive.
///
/// Use it for the value objects a [GenUiWidget] parameter takes: a table row,
/// a chart point, a list item. The `genui_gen_builder` package reads the
/// annotated class's constructor (the unnamed one by default, or [constructor]
/// when set) with the same rules it applies to a widget, and generates two
/// things from it: a JSON schema describing the object, and a decoder that
/// rebuilds an instance from the map the model produced.
///
/// ```dart
/// @GenUiData(description: 'One row of a comparison table.')
/// class TableRow {
///   const TableRow({required this.label, required this.value, this.trend});
///
///   /// Text shown in the first column.
///   final String label;
///
///   /// Numeric value shown in the second column.
///   final double value;
///
///   /// Direction of the change, if known.
///   final Trend? trend;
/// }
///
/// @GenUiWidget(description: 'A comparison table.')
/// class ComparisonTable extends StatelessWidget {
///   const ComparisonTable({super.key, required this.rows});
///
///   /// The rows to display.
///   final List<TableRow> rows;
///   // ...
/// }
/// ```
///
/// A data class holds data, not components: its fields may be the scalar types
/// [GenUiWidget] supports (`String`, `int`, `double`, `num`, `bool`, enums,
/// `List<String>`), other `@GenUiData` classes, or lists of them. `Widget` and
/// callback fields are a build error, because the model emits a data object as
/// a literal value and cannot reference a component from inside one.
///
/// [GenUiProp] applies to the constructor parameters of a data class exactly
/// as it does to a widget's, so `description`, `name` and `ignore` all work.
///
/// Schemas are inlined wherever the class is used rather than referenced, so a
/// data class that reaches itself, directly or through another data class, is
/// a build error.
@Target({TargetKind.classType})
class GenUiData {
  /// Creates a [GenUiData] annotation.
  ///
  /// Unlike [GenUiWidget.description], the description is optional: a data
  /// class is only ever emitted inside a property whose own description
  /// already tells the model what it is for. Supplying one still helps.
  const GenUiData({this.description, this.constructor});

  /// A description of the object, used as the schema description.
  final String? description;

  /// The named constructor to derive the schema and the decoder from.
  ///
  /// When `null` the unnamed constructor is used.
  final String? constructor;
}

/// Marks a `void Function(T)` parameter as writing the user's value back to
/// the data model.
///
/// A `@GenUiWidget` property is read-only on its own: the model puts a value
/// there and the widget displays it. A control the user operates — a switch, a
/// slider, a text field — also has to report the new value back, and genui's
/// own basic catalog does that by writing it into the surface's data model. A
/// parameter annotated with [GenUiWrites] does the same: the generated builder
/// passes a callback that writes to the property named by [property].
///
/// ```dart
/// @GenUiWidget(description: 'A labelled on/off switch.')
/// class LabeledSwitch extends StatelessWidget {
///   const LabeledSwitch({
///     super.key,
///     required this.label,
///     required this.value,
///     @GenUiWrites('value') this.onChanged,
///   });
///
///   /// Text shown next to the switch.
///   final String label;
///
///   /// Whether the switch is on.
///   final bool value;
///
///   /// Called with the new state when the user flips it.
///   final ValueChanged<bool>? onChanged;
///   // ...
/// }
/// ```
///
/// The callback itself is not a schema property — the model never supplies it.
/// What the model supplies is the binding on [property], and the value is
/// written back to that same path, so `{"value": {"path": "/form/notify"}}`
/// makes `/form/notify` hold whatever the user chose. When the model sends a
/// literal instead of a binding there is nowhere it named to write to, so the
/// value goes to `<componentId>.<property>`, which is what genui's own
/// `TextField` does. The widget stays interactive either way.
///
/// [property] must name another property of the same widget, and the
/// callback's argument type must match it: `ValueChanged<bool>` writes to a
/// `bool` property, `ValueChanged<Trend>` to a `Trend` one. Anything else is a
/// build error that names both sides.
///
/// The argument type may not be nullable. A2UI has no agreed meaning for
/// writing `null` to a path — it is read as "clear this" by some
/// implementations and "store null" by others — so `ValueChanged<String?>` is
/// rejected rather than given one of the two meanings silently.
@Target({TargetKind.parameter, TargetKind.field})
class GenUiWrites {
  /// Creates a [GenUiWrites] annotation.
  const GenUiWrites(this.property);

  /// The name of the property this callback writes to.
  ///
  /// This is the *schema* name, so it is the one given by
  /// `@GenUiProp(name: ...)` when the property was renamed, not the Dart
  /// parameter name.
  final String property;
}
