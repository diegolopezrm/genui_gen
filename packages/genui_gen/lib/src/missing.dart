import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';

/// Keys (`surfaceId/componentId/property`) already reported through
/// [genUiReportMissing], so each missing property is sent to the model once
/// per component instance rather than once per rebuild.
final Set<String> _reportedMissing = <String>{};

/// Reports that the required [property] of the component [node] renders is
/// missing or could not be converted, once per component instance.
///
/// Generated builders call this helper right before substituting a fallback
/// for a required property. The report is skipped when the raw value is a
/// `{"path": ...}` or `{"call": ...}` binding: those legitimately resolve to
/// `null` until the data model is populated (for example when the component
/// update arrives before the data model update), and the component rebuilds
/// on its own once the value is available. Only literals the model actually
/// omitted or sent with the wrong type are reported.
///
/// The error is dispatched on the surface as `VALIDATION_FAILED`, with the
/// property as its path, so it reaches the app's `onError` listener and, from
/// there, the model.
///
/// [component] is the catalog item name, used in the message. Never throws.
void genUiReportMissing(
  ComponentNode<ComponentApi> node,
  String component,
  String property,
) {
  final ComponentContext? context = node.context;
  if (context == null) return;
  final Object? raw = context.componentModel.properties[property];
  if (raw is Map && (raw.containsKey('path') || raw.containsKey('call'))) {
    return;
  }
  final SurfaceModel surface = context.surface;
  final String key = '${surface.id}/${node.componentId}/$property';
  if (!_reportedMissing.add(key)) return;
  unawaited(
    surface.dispatchError(
      A2uiRendererError(
        code: A2uiRendererError.validationFailedCode,
        surfaceId: surface.id,
        path: property,
        message:
            '$component: required property "$property" is missing or could '
            'not be resolved.',
      ),
    ),
  );
}

/// Forgets every property reported so far, so it can be reported again.
///
/// Intended for tests.
void genUiResetMissingReports() => _reportedMissing.clear();
