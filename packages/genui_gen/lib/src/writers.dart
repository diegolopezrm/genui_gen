import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'coerce.dart';

final Logger _log = Logger('genui_gen');

/// Builds the callback a `@GenUiWrites` parameter receives: one that writes
/// the user's value to the data path [property] is bound to.
///
/// Returns `null` when the agent sent [property] as a literal, which names no
/// path to write to. A basic control with a literal value is read-only, and
/// so is a generated one: a nullable callback reaches the widget as `null`,
/// so it can show itself disabled.
///
/// [encode] turns the Dart value into one the data model can hold; generated
/// code passes it for enums, which travel as their name.
///
/// The callback never throws. A write the data model rejects, such as a path
/// through a number, is the agent's error to see rather than a crash inside a
/// gesture handler, so it is reported on the surface's `onError` with the data
/// model's own code, as the basic controls report it.
ValueChanged<T>? genUiWriter<T>(
  BuildContext context,
  ComponentProps props,
  String property, {
  Object? Function(T value)? encode,
}) {
  final WritableBinding<Object?>? binding = props.writable(property);
  if (binding == null) return null;
  final SurfaceModel<ComponentImplementation>? surface = A2uiSurface.maybeOf(
    context,
  );
  return (T value) {
    try {
      binding.set(encode == null ? value : encode(value));
    } on A2uiDataError catch (error, stackTrace) {
      _log.warning(
        'Writing "$property" to `${binding.path}` failed',
        error,
        stackTrace,
      );
      if (surface == null) return;
      unawaited(
        surface.dispatchError(
          A2uiRendererError(
            code: error.code,
            surfaceId: surface.id,
            message: error.message,
            path: error.path,
          ),
        ),
      );
    }
  };
}

/// The fields already reported for each node, so that a rebuild does not
/// report the same field again.
final Expando<Set<String>> _reported = Expando('genUiMissingIn');

/// The reporter a generated builder hands the decoder of a `@GenUiData`
/// [property] of [node].
///
/// A literal object was checked against the schema when its message arrived,
/// so a required field missing here means the object came from the data
/// model, where nothing checked it. That is the agent's to fix, so each such
/// field is reported once per node on the surface's `onError`, which an app
/// forwards to the agent, as a validation failure naming
/// `/<property>/<field>`. A field of a nested object, which its decoder names
/// `<outer>.<field>`, gets one segment per level.
///
/// Reported after the current frame rather than during the build, so that an
/// `onError` listener may call `setState`.
GenUiMissingFieldReporter genUiMissingIn(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  String property,
) {
  final SurfaceModel<ComponentImplementation>? surface = A2uiSurface.maybeOf(
    context,
  );
  return (field) {
    final Set<String> reported = _reported[node] ??= <String>{};
    if (!reported.add('$property.$field')) return;
    if (surface == null) {
      _log.warning(
        'Component "${node.componentId}" is missing "$property.$field", and '
        'is not inside an A2uiSurface to report it on.',
      );
      return;
    }
    scheduleMicrotask(() {
      if (node.disposed) return;
      unawaited(
        surface.dispatchError(
          A2uiRendererError(
            code: A2uiRendererError.validationFailedCode,
            surfaceId: surface.id,
            path: '/${[property, ...field.split('.')].map(_escape).join('/')}',
            message:
                'Component "${node.componentId}" needs "$field" in its '
                '"$property", and the value at its data path has none.',
          ),
        ),
      );
    });
  };
}

/// [segment] as one segment of a JSON pointer.
String _escape(String segment) =>
    segment.replaceAll('~', '~0').replaceAll('/', '~1');
