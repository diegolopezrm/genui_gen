import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

/// The body of a synchronous catalog function.
typedef GenUiFunctionBody =
    Object? Function(Map<String, Object?> args, DataContext context);

/// The body of a catalog function that answers once, later.
typedef GenUiAsyncFunctionBody =
    Future<Object?> Function(Map<String, Object?> args, DataContext context);

/// The body of a catalog function that keeps answering.
typedef GenUiStreamFunctionBody =
    Stream<Object?> Function(Map<String, Object?> args, DataContext context);

/// A [FunctionImplementation] whose schema and argument handling are
/// generated.
///
/// The generated code for a `@GenUiFunction` builds one of these: the name,
/// the description and the argument schema come from the annotated function's
/// signature, and the body unpacks each argument out of the `args` map,
/// coerces it and calls the real function.
///
/// Writing one by hand is fine too, and is what the generated code is doing:
///
/// ```dart
/// final FunctionImplementation initials = GenUiClientFunction(
///   name: 'initials',
///   description: 'Returns the initials of a full name.',
///   argumentSchema: S.object(
///     properties: {'name': CommonSchemas.dynamicString},
///     required: ['name'],
///   ),
///   returnType: A2uiReturnType.string,
///   body: (args, context) => _initialsOf(args['name'] as String),
/// );
/// ```
///
/// Declare an argument the agent may bind to a path with a `CommonSchemas`
/// dynamic type, as the generated code does: the renderer checks the
/// arguments of a call against [argumentSchema] when the message arrives,
/// before it resolves them, and hands [execute] the resolved values.
///
/// A function is reactive: the expression system re-invokes it whenever its
/// arguments change, so a synchronous body does not have to watch them. A body
/// that has its own source of change — a clock, a request, a path it watches
/// through the [DataContext] — wants [GenUiClientFunction.streaming] instead,
/// and one that answers once but later wants [GenUiClientFunction.async].
///
/// A throw inside a body is reported by the renderer as an `EXECUTION_ERROR`
/// rather than escaping the expression that called it.
class GenUiClientFunction extends FunctionImplementation {
  /// Creates a function that answers immediately.
  GenUiClientFunction({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiFunctionBody body,
  }) : _run = body;

  /// Creates a function that answers once, later.
  ///
  /// From an action the renderer awaits the answer. In a bound property the
  /// value is `null` until the answer arrives, and the property updates then.
  GenUiClientFunction.async({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiAsyncFunctionBody body,
  }) : _run = _later(body);

  /// Creates a function that keeps answering as its own sources change.
  ///
  /// From an action the renderer awaits the first answer. In a bound property
  /// the value is `null` until the first answer arrives, and the property
  /// follows the answers after that.
  GenUiClientFunction.streaming({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiStreamFunctionBody body,
  }) : _run = _following(body);

  final GenUiFunctionBody _run;

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => _run(args, context);
}

/// A body whose [Future] an action awaits and a bound property watches.
///
/// The renderer awaits a returned `Future` only when the function runs from an
/// action. A bound property needs a signal instead, and the same one each time
/// the renderer re-invokes the function with the same arguments, which it
/// does as soon as the signal changes.
GenUiFunctionBody _later(GenUiAsyncFunctionBody body) {
  final _Answers answers = _Answers();
  return (args, context) {
    if (context.isUserActivated) return body(args, context);
    return answers.of(args, (answer) {
      body(args, context).then(
        (value) => answer.target?.value = value,
        // A failure leaves the property empty, as a stream error did.
        onError: (Object _) {},
      );
      return null;
    });
  };
}

/// A body whose first answer an action awaits and whose answers a bound
/// property follows.
GenUiFunctionBody _following(GenUiStreamFunctionBody body) {
  final _Answers answers = _Answers();
  return (args, context) {
    if (context.isUserActivated) return body(args, context).first;
    return answers.of(args, (answer) {
      return body(
        args,
        context,
      ).listen((value) => answer.target?.value = value, onError: (Object _) {});
    });
  };
}

/// The signals a bound property watches, by the arguments they answer for.
///
/// Held weakly, so an answer nobody watches any more is collected, and the
/// stream subscription feeding it, if any, is cancelled when it is.
class _Answers {
  final Map<String, WeakReference<Signal<Object?>>> _byArgs =
      <String, WeakReference<Signal<Object?>>>{};

  final Finalizer<StreamSubscription<Object?>> _cancel =
      Finalizer<StreamSubscription<Object?>>(
        (subscription) => unawaited(subscription.cancel()),
      );

  /// The signal answering for [args], started with [start] the first time.
  ///
  /// [start] receives a weak reference to the signal, so whatever it starts
  /// does not keep the signal alive, and may return the subscription to
  /// cancel once the signal is collected.
  Signal<Object?> of(
    Map<String, Object?> args,
    StreamSubscription<Object?>? Function(WeakReference<Signal<Object?>> answer)
    start,
  ) {
    final String key = _keyOf(args);
    final Signal<Object?>? existing = _byArgs[key]?.target;
    if (existing != null) return existing;
    _byArgs.removeWhere((_, answer) => answer.target == null);
    final Signal<Object?> answer = signal<Object?>(null);
    final WeakReference<Signal<Object?>> reference = WeakReference(answer);
    _byArgs[key] = reference;
    final StreamSubscription<Object?>? subscription = start(reference);
    if (subscription != null) _cancel.attach(answer, subscription);
    return answer;
  }

  static String _keyOf(Map<String, Object?> args) {
    try {
      return jsonEncode(args);
    } on JsonUnsupportedObjectError {
      return '$args';
    }
  }
}
