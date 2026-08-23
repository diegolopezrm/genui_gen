import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// Builds a [VoidCallback] that performs an A2UI action the same way the core
/// `Button` does.
///
/// Returns `null` when [actionData] is `null`, so widgets that treat a `null`
/// callback as "disabled" keep that behavior when the model omits the action.
///
/// Supported shapes of [actionData]:
///
/// * `{"event": {"name": "...", "context": {...}}}` resolves `context`
///   against `ctx.dataContext` and dispatches a [UserActionEvent] with
///   `sourceComponentId` set to `ctx.id`.
/// * `{"functionCall": {"call": "...", "args": {...}}}` resolves the call
///   through `ctx.dataContext.resolve`. `closeModal` pops the current route.
///
/// The returned callback never throws: every failure is reported through
/// `ctx.reportError` and logged with genui's logger. Malformed action data is
/// reported as an [A2uiValidationException] so the model receives the actual
/// message (genui forwards other error types as a generic internal error).
VoidCallback? genUiActionHandler(CatalogItemContext ctx, Object? actionData) {
  if (actionData == null) return null;
  return () {
    unawaited(_perform(ctx, actionData));
  };
}

Future<void> _perform(CatalogItemContext ctx, Object actionData) async {
  try {
    if (actionData is! Map) {
      throw A2uiValidationException(
        'Action for component "${ctx.id}" must be an object with an "event" '
        'or "functionCall" key, got ${actionData.runtimeType}.',
        surfaceId: ctx.surfaceId,
        path: ctx.id,
        json: actionData,
      );
    }
    final JsonMap action = actionData.cast<String, Object?>();
    if (action.containsKey('event')) {
      await _dispatchEvent(ctx, action['event']);
    } else if (action.containsKey('functionCall')) {
      await _callFunction(ctx, action['functionCall']);
    } else {
      genUiLogger.warning(
        'Action for component "${ctx.id}" has neither "event" nor '
        '"functionCall": $action',
      );
    }
  } catch (error, stackTrace) {
    genUiLogger.severe(
      'Action for component "${ctx.id}" failed',
      error,
      stackTrace,
    );
    _report(ctx, error, stackTrace);
  }
}

Future<void> _dispatchEvent(CatalogItemContext ctx, Object? event) async {
  if (event is! Map) {
    throw A2uiValidationException(
      'Action "event" for component "${ctx.id}" must be an object, got '
      '${event.runtimeType}.',
      surfaceId: ctx.surfaceId,
      path: ctx.id,
      json: event,
    );
  }
  final Object? name = event['name'];
  if (name is! String || name.isEmpty) {
    throw A2uiValidationException(
      'Action "event" for component "${ctx.id}" is missing a "name".',
      surfaceId: ctx.surfaceId,
      path: ctx.id,
      json: event,
    );
  }
  final Object? contextDefinition = event['context'];
  final JsonMap resolvedContext = await resolveContext(
    ctx.dataContext,
    contextDefinition is Map ? contextDefinition.cast<String, Object?>() : null,
  );
  ctx.dispatchEvent(
    UserActionEvent(
      name: name,
      sourceComponentId: ctx.id,
      context: resolvedContext,
    ),
  );
}

Future<void> _callFunction(CatalogItemContext ctx, Object? functionCall) async {
  if (functionCall is! Map) {
    throw A2uiValidationException(
      'Action "functionCall" for component "${ctx.id}" must be an object, got '
      '${functionCall.runtimeType}.',
      surfaceId: ctx.surfaceId,
      path: ctx.id,
      json: functionCall,
    );
  }
  final JsonMap call = functionCall.cast<String, Object?>();
  final Object? callName = call['call'];
  if (callName is! String || callName.isEmpty) {
    throw A2uiValidationException(
      'Action "functionCall" for component "${ctx.id}" is missing a "call".',
      surfaceId: ctx.surfaceId,
      path: ctx.id,
      json: functionCall,
    );
  }

  if (callName == 'closeModal') {
    if (ctx.buildContext.mounted) {
      Navigator.of(ctx.buildContext).pop();
    }
    return;
  }

  final Stream<Object?> resultStream = ctx.dataContext.resolve(call);
  final iterator = StreamIterator<Object?>(resultStream);
  try {
    await iterator.moveNext().timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('Function execution for $callName timed out'),
    );
  } catch (exception, stackTrace) {
    genUiLogger.severe(
      'Error executing function call "$callName" for component "${ctx.id}"',
      exception,
      stackTrace,
    );
    final A2uiFunctionException reported = switch (exception) {
      A2uiFunctionException() => exception,
      TimeoutException() => A2uiFunctionException(
        'Function execution timed out.',
        functionName: callName,
        cause: exception,
      ),
      _ => A2uiFunctionException(
        'Function execution failed. Please check arguments and try again.',
        functionName: callName,
        cause: exception,
      ),
    };
    // Report before cancelling the iterator, like the core Button does, so
    // the error surfaces even if cancellation is slow.
    _report(ctx, reported, stackTrace);
  } finally {
    await iterator.cancel();
  }
}

void _report(CatalogItemContext ctx, Object error, StackTrace stackTrace) {
  try {
    ctx.reportError(error, stackTrace);
  } catch (reportingError, reportingStackTrace) {
    genUiLogger.severe(
      'reportError threw while handling an action failure for component '
      '"${ctx.id}"',
      reportingError,
      reportingStackTrace,
    );
  }
}
