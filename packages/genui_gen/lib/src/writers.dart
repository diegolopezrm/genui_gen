import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

/// Builds the callback that writes a control's new value into the surface's
/// data model.
///
/// [props] are the resolved properties of the component [node] renders, and
/// [property] the one the control reflects. When the model bound it to a
/// `{"path": ...}`, the value is written to that path, so the model reads the
/// result back from the place it named. When it sent a literal — or nothing —
/// there is no path to write to, and the value goes to
/// `<componentId>.<property>` instead, relative to the component's data
/// context, which is where genui's core catalog put it. The returned callback
/// is therefore never `null`: a control always has somewhere to put the user's
/// answer, and [genUiWrittenValue] reads it back from there.
///
/// [encode] converts the Dart value into something the data model can carry;
/// generated code passes it for enums, which travel as their name.
///
/// The returned callback never throws. A path the model chose badly — writing
/// through a primitive, say — makes the data model raise. That is the model's
/// error to see, not a crash inside a gesture handler, so it is dispatched on
/// the surface, which reports it to the app's `onError` listener.
ValueChanged<T> genUiValueWriter<T>(
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  String property, {
  Object? Function(T value)? encode,
}) {
  final String path = genUiWritePath(node, props, property);
  return (T value) {
    final ComponentContext? context = node.context;
    if (context == null) return;
    try {
      // Relative to the component's data context, which is how the renderer
      // resolves the binding too.
      context.dataContext.set(path, encode == null ? value : encode(value));
    } catch (error) {
      _report(context, node, error, path: path, property: property);
    }
  };
}

/// The data model path a control writes to for [property].
///
/// The path the model bound the property to, or `<componentId>.<property>`
/// when it sent a literal. Exposed because a widget that writes more than one
/// property at once may want the path itself.
String genUiWritePath(
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  String property,
) => _boundPath(props, property) ?? _fallbackPath(node, property);

/// The value a control shows for a [property] it also writes to.
///
/// A property some callback writes to cannot be read from the literal the
/// model sent: once the user has changed it, the answer lives in the data
/// model. When the model bound the property, that is the bound value. When it
/// sent a literal, it is what [genUiValueWriter] wrote to
/// `<componentId>.<property>`, and the literal for as long as that path holds
/// nothing — which is what a text field does with its initial value.
///
/// Called while the component builds, the read is tracked, so the component
/// rebuilds when the user writes a new value.
Object? genUiWrittenValue(
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  String property,
) {
  if (_boundPath(props, property) != null) return props.value(property);
  final ComponentContext? context = node.context;
  if (context != null) {
    final String path = context.dataContext.resolvePath(
      _fallbackPath(node, property),
    );
    final Object? written = context.surface.dataModel
        .watch<Object?>(path)
        .value;
    if (written != null) return written;
  }
  return props.value(property);
}

/// The path the model bound [property] to, unless it bound it to nothing.
String? _boundPath(ComponentProps props, String property) {
  final String? path = props.writable(property)?.path;
  return path == null || path.isEmpty ? null : path;
}

String _fallbackPath(
  ComponentNode<ComponentImplementation> node,
  String property,
) => '${node.componentId}.$property';

void _report(
  ComponentContext context,
  ComponentNode<ComponentImplementation> node,
  Object error, {
  required String path,
  required String property,
}) {
  final String message =
      'Component "${node.componentId}" could not write "$property" to '
      '`$path`: ${error is A2uiError ? error.message : error}';
  unawaited(
    context.surface.dispatchError(
      A2uiRendererError(
        code: error is A2uiDataError ? error.code : 'DATA_ERROR',
        surfaceId: context.surface.id,
        message: message,
        path: error is A2uiDataError ? error.path : path,
      ),
    ),
  );
}
