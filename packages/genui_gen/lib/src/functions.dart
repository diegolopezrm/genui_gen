import 'dart:async';

import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

// Re-exported for the same reason as `S`: a file that only declares catalog
// functions names these two in its generated part, and should not have to
// import genui to get them.
export 'package:genui/genui.dart'
    show A2uiSchemas, ClientFunction, ClientFunctionReturnType;

/// The body of a synchronous catalog function.
typedef GenUiFunctionBody =
    Object? Function(JsonMap args, ExecutionContext context);

/// The body of a catalog function that answers once, later.
typedef GenUiAsyncFunctionBody =
    Future<Object?> Function(JsonMap args, ExecutionContext context);

/// The body of a catalog function that keeps answering.
typedef GenUiStreamFunctionBody =
    Stream<Object?> Function(JsonMap args, ExecutionContext context);

/// A [ClientFunction] whose schema and argument handling are generated.
///
/// The generated code for a `@GenUiFunction` builds one of these: the name,
/// the description and the argument schema come from the annotated function's
/// signature, and the body unpacks each argument out of the `args` map,
/// coerces it and calls the real function.
///
/// Writing one by hand is fine too, and is what the generated code is doing:
///
/// ```dart
/// final ClientFunction initials = GenUiClientFunction(
///   name: 'initials',
///   description: 'Returns the initials of a full name.',
///   argumentSchema: S.object(
///     properties: {'name': S.string(description: 'A full name.')},
///     required: ['name'],
///   ),
///   returnType: ClientFunctionReturnType.string,
///   body: (args, context) => _initialsOf(args['name'] as String),
/// );
/// ```
///
/// A function is reactive: the expression system re-invokes it whenever its
/// arguments change, so a synchronous body does not have to watch them. A body
/// that has its own source of change — a clock, a request, a path it
/// subscribes to through [ExecutionContext] — wants
/// [GenUiClientFunction.streaming] instead, and one that answers once but
/// later wants [GenUiClientFunction.async].
class GenUiClientFunction implements ClientFunction {
  /// Creates a function that answers immediately.
  ///
  /// A throw inside [body] becomes an error on the returned stream rather than
  /// an exception out of the expression that called it.
  GenUiClientFunction({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = ClientFunctionReturnType.any,
    required GenUiFunctionBody body,
  }) : _run = ((args, context) {
         try {
           return Stream<Object?>.value(body(args, context));
         } catch (error, stackTrace) {
           return Stream<Object?>.error(error, stackTrace);
         }
       });

  /// Creates a function that answers once, later.
  GenUiClientFunction.async({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = ClientFunctionReturnType.any,
    required GenUiAsyncFunctionBody body,
  }) : _run = ((args, context) {
         try {
           return Stream<Object?>.fromFuture(body(args, context));
         } catch (error, stackTrace) {
           return Stream<Object?>.error(error, stackTrace);
         }
       });

  /// Creates a function that keeps answering as its own sources change.
  GenUiClientFunction.streaming({
    required this.name,
    required this.description,
    required this.argumentSchema,
    this.returnType = ClientFunctionReturnType.any,
    required GenUiStreamFunctionBody body,
  }) : _run = ((args, context) {
         try {
           return body(args, context);
         } catch (error, stackTrace) {
           return Stream<Object?>.error(error, stackTrace);
         }
       });

  @override
  final String name;

  @override
  final String description;

  @override
  final Schema argumentSchema;

  @override
  final ClientFunctionReturnType returnType;

  final GenUiStreamFunctionBody _run;

  @override
  Stream<Object?> execute(JsonMap args, ExecutionContext context) =>
      _run(args, context);
}
