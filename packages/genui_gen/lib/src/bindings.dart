import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// Rebuilds a `T` from the JSON map the model produced for it.
///
/// Generated code passes one of these for every `@GenUiData` property: the
/// binding resolves the property to a map (or a list of maps), and the decoder
/// turns each map into the Dart object the widget constructor expects.
/// Decoding always happens after resolution, never inside the runtime.
typedef GenUiDecoder<T> = T Function(Map<String, Object?> json);

/// A typed description of how to resolve one property value.
///
/// The [raw] value is whatever the model emitted for the property: a literal,
/// a `{"path": "/some/path"}` data binding or a `{"call": ...}` function
/// call. [GenUiBindings] hands each binding to the matching genui `Bound*`
/// widget, so resolution semantics are exactly genui's.
sealed class GenUiBinding {
  const GenUiBinding._(this.raw);

  /// Binds a `String` value (resolved with genui's `BoundString`).
  const factory GenUiBinding.string(Object? raw) = _StringBinding;

  /// Binds a `num` value (resolved with genui's `BoundNumber`).
  const factory GenUiBinding.number(Object? raw) = _NumberBinding;

  /// Binds a `bool` value (resolved with genui's `BoundBool`).
  const factory GenUiBinding.bool(Object? raw) = _BoolBinding;

  /// Binds a `List<String>` value (resolved with genui's `BoundList`; each
  /// non-null element is converted with `toString()`).
  const factory GenUiBinding.stringList(Object? raw) = _StringListBinding;

  /// Binds a single JSON object (resolved with genui's `BoundObject`).
  ///
  /// The resolved value is exposed as a `Map<String, Object?>` through
  /// [GenUiValues.object]; anything that is not a map resolves to `null`.
  const factory GenUiBinding.object(Object? raw) = _ObjectBinding;

  /// Binds a list of JSON objects (resolved with genui's `BoundList`).
  ///
  /// The resolved value is exposed as a `List<Map<String, Object?>>` through
  /// [GenUiValues.objectList]; entries that are not maps are skipped.
  const factory GenUiBinding.objectList(Object? raw) = _ObjectListBinding;

  /// The literal, `{"path": ...}` or `{"call": ...}` value to resolve.
  final Object? raw;
}

final class _StringBinding extends GenUiBinding {
  const _StringBinding(super.raw) : super._();
}

final class _NumberBinding extends GenUiBinding {
  const _NumberBinding(super.raw) : super._();
}

final class _BoolBinding extends GenUiBinding {
  const _BoolBinding(super.raw) : super._();
}

final class _StringListBinding extends GenUiBinding {
  const _StringListBinding(super.raw) : super._();
}

final class _ObjectBinding extends GenUiBinding {
  const _ObjectBinding(super.raw) : super._();
}

final class _ObjectListBinding extends GenUiBinding {
  const _ObjectListBinding(super.raw) : super._();
}

/// Typed accessors over the values resolved by [GenUiBindings].
///
/// Every accessor returns `null` when the key was not bound or when the
/// resolved value could not be converted to the requested type (the same
/// rules genui's `Bound*` widgets apply).
class GenUiValues {
  /// Creates a [GenUiValues] over already resolved values.
  const GenUiValues(this._values);

  /// A [GenUiValues] with no values at all.
  static const GenUiValues empty = GenUiValues({});

  final Map<String, Object?> _values;

  /// The resolved `String` for [key], if any.
  String? string(String key) => _values[key] as String?;

  /// The resolved `num` for [key], if any.
  num? number(String key) => _values[key] as num?;

  /// The resolved `bool` for [key], if any.
  bool? boolean(String key) => _values[key] as bool?;

  /// The resolved `List<String>` for [key], if any.
  List<String>? stringList(String key) => _values[key] as List<String>?;

  /// The resolved JSON object for [key], if any.
  ///
  /// Returns `null` when the key was not bound or when the resolved value is
  /// not a map, so a model that emits the wrong shape degrades instead of
  /// throwing inside `build`.
  Map<String, Object?>? object(String key) => _asObject(_values[key]);

  /// The resolved list of JSON objects for [key], if any.
  ///
  /// Returns `null` when the key was not bound or when the resolved value is
  /// not a list. Entries of the list that are not maps are skipped rather than
  /// reported: the model can emit junk inside an otherwise valid list, and
  /// dropping the bad entries keeps the good ones usable.
  List<Map<String, Object?>>? objectList(String key) {
    final Object? value = _values[key];
    if (value is List<Map<String, Object?>>) return value;
    if (value is List) return _asObjectList(value);
    return null;
  }

  /// The raw resolved value for [key], if any.
  Object? operator [](String key) => _values[key];

  /// Whether [key] resolved to a non-null value.
  bool has(String key) => _values[key] != null;

  /// The keys with a resolved (possibly `null`) value.
  Iterable<String> get keys => _values.keys;

  @override
  String toString() => 'GenUiValues($_values)';
}

/// Signature of the builder invoked by [GenUiBindings] once every binding has
/// been resolved.
typedef GenUiValuesWidgetBuilder =
    Widget Function(BuildContext context, GenUiValues values);

/// Resolves a set of literal-or-bound values against a [DataContext] and calls
/// [builder] once with all of them resolved.
///
/// Internally the bindings are folded into a chain of genui `BoundString`,
/// `BoundNumber`, `BoundBool`, `BoundList` and `BoundObject` widgets, so data
/// bindings and function calls behave exactly as they do in the core catalog,
/// and the widget rebuilds whenever any bound value changes in the data model.
///
/// With an empty [bindings] map, [builder] is called directly.
///
/// ```dart
/// GenUiBindings(
///   dataContext: ctx.dataContext,
///   bindings: {
///     'title': GenUiBinding.string(data['title']),
///     'price': GenUiBinding.number(data['price']),
///   },
///   builder: (context, v) => ProductCard(
///     title: v.string('title') ?? '',
///     price: (v.number('price') ?? 0).toDouble(),
///   ),
/// );
/// ```
class GenUiBindings extends StatelessWidget {
  /// Creates a [GenUiBindings] widget.
  const GenUiBindings({
    super.key,
    required this.dataContext,
    required this.bindings,
    required this.builder,
  });

  /// The [DataContext] the bindings are resolved against.
  final DataContext dataContext;

  /// The bindings to resolve, keyed by property name.
  ///
  /// Iteration order determines the nesting order of the underlying `Bound*`
  /// widgets; generated code always uses a fixed literal map, so the order is
  /// stable across rebuilds.
  final Map<String, GenUiBinding> bindings;

  /// Called with the resolved values once all bindings have been resolved.
  final GenUiValuesWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    if (bindings.isEmpty) {
      return builder(context, GenUiValues.empty);
    }
    final List<MapEntry<String, GenUiBinding>> entries = bindings.entries
        .toList(growable: false);
    return _bind(context, entries, 0, const <String, Object?>{});
  }

  Widget _bind(
    BuildContext context,
    List<MapEntry<String, GenUiBinding>> entries,
    int index,
    Map<String, Object?> resolved,
  ) {
    if (index == entries.length) {
      return builder(context, GenUiValues(Map.unmodifiable(resolved)));
    }

    final MapEntry<String, GenUiBinding> entry = entries[index];
    final String name = entry.key;
    final Key key = ValueKey<String>(name);

    Widget next(BuildContext innerContext, Object? value) {
      return _bind(innerContext, entries, index + 1, <String, Object?>{
        ...resolved,
        name: value,
      });
    }

    return switch (entry.value) {
      _StringBinding(:final raw) => BoundString(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: next,
      ),
      _NumberBinding(:final raw) => BoundNumber(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: next,
      ),
      _BoolBinding(:final raw) => BoundBool(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: next,
      ),
      _StringListBinding(:final raw) => BoundList(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: (innerContext, list) => next(innerContext, _toStrings(list)),
      ),
      _ObjectBinding(:final raw) => BoundObject(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: (innerContext, value) => next(innerContext, _asObject(value)),
      ),
      _ObjectListBinding(:final raw) => BoundList(
        key: key,
        dataContext: dataContext,
        value: raw,
        builder: (innerContext, list) =>
            next(innerContext, list == null ? null : _asObjectList(list)),
      ),
    };
  }

  static List<String>? _toStrings(List<Object?>? list) {
    if (list == null) return null;
    return list
        .where((Object? element) => element != null)
        .map((Object? element) => element.toString())
        .toList(growable: false);
  }
}

/// Views [value] as a JSON object, or returns `null` when it is not a map.
Map<String, Object?>? _asObject(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key.toString(): entry.value,
    };
  }
  return null;
}

/// Views [list] as a list of JSON objects, skipping every entry that is not a
/// map.
List<Map<String, Object?>> _asObjectList(List<Object?> list) {
  final List<Map<String, Object?>> objects = <Map<String, Object?>>[];
  for (final Object? element in list) {
    final Map<String, Object?>? object = _asObject(element);
    if (object != null) objects.add(object);
  }
  return List<Map<String, Object?>>.unmodifiable(objects);
}
