import 'dart:async';
import 'dart:collection';
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
///     properties: {'name': GenUiSchemas.string(description: 'A full name.')},
///     required: ['name'],
///   ),
///   returnType: A2uiReturnType.string,
///   body: (args, context) => _initialsOf(args['name'] as String),
/// );
/// ```
///
/// A function is reactive: a2ui_core calls it again whenever its arguments
/// change, so a synchronous body does not have to watch them. A body that
/// answers later wants [GenUiClientFunction.async], and one with its own
/// source of change, such as a clock, wants [GenUiClientFunction.streaming].
class GenUiClientFunction extends FunctionImplementation {
  /// Creates a function that answers immediately.
  ///
  /// A throw inside [body] is reported by a2ui_core on the surface, as an
  /// expression error naming the function, and the value is `null`.
  GenUiClientFunction({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiFunctionBody body,
  }) : _execute = body;

  /// Creates a function that answers once, later.
  ///
  /// The value is `null` until the future completes. a2ui_core evaluates a
  /// function again each time anything it depends on changes, so the answer
  /// is kept for its arguments: the same arguments get the same answer, not
  /// a second call. A future that fails is reported the way a synchronous
  /// throw is, and the next evaluation calls [body] again.
  GenUiClientFunction.async({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiAsyncFunctionBody body,
  }) : _execute = _Answers((args, context, answer) {
         final Future<Object?> future = body(args, context);
         future.then(answer.complete, onError: answer.fail);
         return null;
       }).call;

  /// Creates a function that keeps answering as its own sources change.
  ///
  /// The value is `null` until the stream emits, and then the latest event.
  /// As with [GenUiClientFunction.async], one subscription is kept per set of
  /// arguments, for the [maxAnswers] most recent sets, and cancelled when its
  /// set is dropped. An error ends the subscription and is reported the way a
  /// synchronous throw is.
  GenUiClientFunction.streaming({
    required super.name,
    required String super.description,
    required super.argumentSchema,
    super.returnType,
    required GenUiStreamFunctionBody body,
  }) : _execute = _Answers((args, context, answer) {
         final Stream<Object?> stream = body(args, context);
         return stream.listen(
           answer.complete,
           onError: answer.fail,
           cancelOnError: true,
         );
       }).call;

  /// How many sets of arguments an asynchronous function keeps an answer for.
  static const int maxAnswers = 64;

  final Object? Function(Map<String, Object?> args, DataContext context)
  _execute;

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => _execute(args, context);
}

/// Starts the answer for one set of arguments, returning the subscription to
/// cancel when the answer is dropped, if there is one.
typedef _Start =
    StreamSubscription<Object?>? Function(
      Map<String, Object?> args,
      DataContext context,
      _Answer answer,
    );

/// The answers of an asynchronous body, one per set of arguments.
///
/// a2ui_core reads a function's value inside a computed signal that runs the
/// function again whenever anything it read changes, including the signal the
/// function returned. Handing back the same signal for the same arguments is
/// what lets the answer arrive without starting the call over, the way
/// a2ui_core keeps one call to the agent per set of arguments.
final class _Answers {
  _Answers(this._start);

  final _Start _start;

  /// Least recently used first.
  final LinkedHashMap<String, _Answer> _byArguments = LinkedHashMap();

  Object? call(Map<String, Object?> args, DataContext context) {
    final String key = _keyOf(args);
    final _Answer? existing = _byArguments.remove(key);
    if (existing != null) {
      final Object? error = existing.error;
      if (error != null) {
        // Thrown once, so a2ui_core reports it the way it reports a
        // synchronous throw; dropped, so the next evaluation starts over.
        existing.cancel();
        Error.throwWithStackTrace(error, existing.stackTrace!);
      }
      _byArguments[key] = existing;
      return existing.value;
    }
    final answer = _Answer();
    answer.subscription = _start(args, context, answer);
    _byArguments[key] = answer;
    while (_byArguments.length > GenUiClientFunction.maxAnswers) {
      _byArguments.remove(_byArguments.keys.first)!.cancel();
    }
    return answer.value;
  }

  /// The arguments as canonical JSON, so equal arguments share an answer
  /// whatever order their keys arrived in.
  static String _keyOf(Map<String, Object?> args) =>
      jsonEncode(_canonical(args), toEncodable: (value) => value.toString());

  static Object? _canonical(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {
      for (final String key in map.keys.map((k) => '$k').toList()..sort())
        key: _canonical(map[key]),
    },
    final List<Object?> list => [for (final item in list) _canonical(item)],
    _ => value,
  };
}

/// The answer for one set of arguments.
final class _Answer {
  final Signal<Object?> value = signal<Object?>(null);
  StreamSubscription<Object?>? subscription;
  Object? error;
  StackTrace? stackTrace;

  void complete(Object? result) => value.value = result;

  void fail(Object error, StackTrace stackTrace) {
    this.error = error;
    this.stackTrace = stackTrace;
    // A value nothing else holds, so the signal changes and the computed
    // reading it runs the function again, which throws the error.
    value.value = _Failed();
  }

  void cancel() => unawaited(subscription?.cancel());
}

final class _Failed {}
