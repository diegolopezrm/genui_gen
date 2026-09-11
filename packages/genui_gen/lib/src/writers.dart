import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

/// Builds the callback that writes a control's new value into the surface's
/// data model, the way genui's own `TextField`, `Slider` and `CheckBox` do.
///
/// [reference] is the raw value the model sent for the property the control
/// reflects. When it is a `{"path": ...}` binding the value is written to that
/// path, so the model reads the result back from the place it named. When it
/// is a literal — or missing — there is no path to write to, and the value
/// goes to `<componentId>.<property>` instead, matching the fallback the core
/// catalog uses. The returned callback is therefore never `null`: a control
/// always has somewhere to put the user's answer.
///
/// [encode] converts the Dart value into something the data model can carry;
/// generated code passes it for enums, which travel as their name.
///
/// The returned callback never throws. genui 0.10 made data model writes
/// stricter, and a path the model chose badly — writing through a primitive,
/// say — now raises. That is the model's error to see, not a crash inside a
/// gesture handler, so it is reported through `ctx.reportError` exactly as a
/// failed action is.
ValueChanged<T> genUiValueWriter<T>(
  CatalogItemContext ctx,
  Object? reference,
  String property, {
  Object? Function(T value)? encode,
}) {
  final String path = genUiWritePath(ctx, reference, property);
  return (T value) {
    try {
      ctx.dataContext.update(
        DataPath(path),
        encode == null ? value : encode(value),
      );
    } catch (error, stackTrace) {
      genUiLogger.severe(
        'Writing "$property" of component "${ctx.id}" to `$path` failed',
        error,
        stackTrace,
      );
      _report(ctx, error, stackTrace, path: path, property: property);
    }
  };
}

/// The data model path a control writes to for [property].
///
/// The path the model bound the property to, or `<componentId>.<property>`
/// when it sent a literal. Exposed because a widget that writes more than one
/// property at once may want the path itself.
String genUiWritePath(
  CatalogItemContext ctx,
  Object? reference,
  String property,
) {
  if (reference is Map) {
    final Object? path = reference['path'];
    if (path is String && path.isNotEmpty) return path;
  }
  return '${ctx.id}.$property';
}

/// The `{"path": ...}` reference a writable property is *read* through.
///
/// A property some callback writes to cannot be read from the raw value the
/// model sent: once the user has changed it, the answer lives in the data
/// model, not in the literal the model wrote. Reading through the same path
/// the value is written to keeps the two in step, and generated code falls
/// back to the literal for as long as that path holds nothing — which is what
/// genui's own `TextField` does with its initial value.
JsonMap genUiWriteReference(
  CatalogItemContext ctx,
  Object? raw,
  String property,
) => <String, Object?>{'path': genUiWritePath(ctx, raw, property)};

void _report(
  CatalogItemContext ctx,
  Object error,
  StackTrace stackTrace, {
  required String path,
  required String property,
}) {
  // Wrapped so the model receives the actual message: genui forwards error
  // types it does not recognise as a generic internal error. The original
  // message is interpolated rather than the error passed through, because the
  // data model's own exceptions come from `a2ui_core`, which this package
  // does not depend on directly.
  final reported = error is A2uiValidationException
      ? error
      : A2uiValidationException(
          'Component "${ctx.id}" could not write "$property" to `$path`: '
          '$error',
          surfaceId: ctx.surfaceId,
          path: ctx.id,
        );
  try {
    ctx.reportError(reported, stackTrace);
  } catch (reportingError, reportingStackTrace) {
    genUiLogger.severe(
      'reportError threw while handling a failed write for component '
      '"${ctx.id}"',
      reportingError,
      reportingStackTrace,
    );
  }
}
