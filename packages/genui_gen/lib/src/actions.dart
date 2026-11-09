import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/widgets.dart';

/// Builds a [VoidCallback] that performs an A2UI action the same way the core
/// `Button` does.
///
/// [action] is what `props.action(...)` returns for the property: the
/// renderer has already read the `{"event": ...}` or `{"functionCall": ...}`
/// the model sent, and calling it resolves the event's `context` against the
/// data model at that moment and runs it as a user activation.
///
/// Returns `null` when [action] is `null`, so widgets that treat a `null`
/// callback as "disabled" keep that behavior when the model omits the action.
///
/// The returned callback never throws. A function call that fails is reported
/// by the renderer on the surface's `onError`, which the app forwards to the
/// agent.
VoidCallback? genUiActionHandler(NodeAction? action) {
  if (action == null) return null;
  return () {
    unawaited(action());
  };
}
