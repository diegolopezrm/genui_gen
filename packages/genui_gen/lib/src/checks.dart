import 'package:meta/meta.dart';

/// What a component's validation checks say about it right now.
///
/// A2UI's `CheckRule` carries a condition and the message to show when it
/// fails. a2ui_core evaluates the rules of a component whose schema declares
/// `checks` and hands the builder the result as `isValid` and
/// `validationErrors`; a `@GenUiChecked` parameter typed [GenUiCheckResult]
/// receives both, with the message of the first rule that fails.
@immutable
class GenUiCheckResult {
  /// Creates a [GenUiCheckResult].
  const GenUiCheckResult({required this.isValid, required this.message});

  /// Every rule passes, or there were no rules.
  ///
  /// A rule whose condition has not resolved yet counts as passing, so a field
  /// is not announced as invalid before the data model arrives.
  final bool isValid;

  /// The message of the first rule that is failing, in the order the agent
  /// listed them, or `null` while everything passes.
  final String? message;

  /// Nothing to complain about.
  static const GenUiCheckResult valid = GenUiCheckResult(
    isValid: true,
    message: null,
  );

  @override
  bool operator ==(Object other) =>
      other is GenUiCheckResult &&
      other.isValid == isValid &&
      other.message == message;

  @override
  int get hashCode => Object.hash(isValid, message);

  @override
  String toString() => isValid ? 'valid' : 'invalid: $message';
}
