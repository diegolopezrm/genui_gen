import 'package:genui/genui.dart';

/// Keys (`surfaceId/componentId/property`) already reported through
/// [genUiReportMissing], so each missing property is sent to the model once
/// per component instance rather than once per rebuild.
final Set<String> _reportedMissing = <String>{};

/// Reports that the required [property] of the component being built by
/// [ctx] is missing or could not be converted, once per component instance.
///
/// Generated builders call this helper right before substituting a fallback
/// for a required property. The report is skipped when the raw value is a
/// `{"path": ...}` or `{"call": ...}` binding: those legitimately resolve to
/// `null` until the data model is populated (for example when the component
/// update arrives before the data model update), and the bound widget
/// rebuilds on its own once the value is available. Only literals the model
/// actually omitted or sent with the wrong type are reported.
///
/// The error is an [A2uiValidationException], the only error type whose
/// message and path genui forwards to the model verbatim.
///
/// [component] is the catalog item name, used in the message. Never throws.
void genUiReportMissing(
  CatalogItemContext ctx,
  String component,
  String property,
) {
  final Object data = ctx.data;
  final Object? raw = data is Map ? data[property] : null;
  if (raw is Map && (raw.containsKey('path') || raw.containsKey('call'))) {
    return;
  }
  final String key = '${ctx.surfaceId}/${ctx.id}/$property';
  if (!_reportedMissing.add(key)) return;
  try {
    ctx.reportError(
      A2uiValidationException(
        '$component: required property "$property" is missing or could not '
        'be resolved.',
        surfaceId: ctx.surfaceId,
        path: property,
      ),
      StackTrace.current,
    );
  } catch (error, stackTrace) {
    genUiLogger.severe(
      'reportError threw while reporting missing property "$property" of '
      'component "${ctx.id}"',
      error,
      stackTrace,
    );
  }
}

/// Forgets every property reported so far, so it can be reported again.
///
/// Intended for tests.
void genUiResetMissingReports() => _reportedMissing.clear();
