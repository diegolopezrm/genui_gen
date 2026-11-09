import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

/// What a component's validation checks say about it right now.
///
/// A2UI's `CheckRule` carries a condition and the message to show when it
/// fails, and both are required. The renderer evaluates the rules one at a
/// time and keeps the message of each one that fails, so a component can show
/// the sentence the agent wrote for the person reading the screen rather than
/// only turn red.
@immutable
class GenUiCheckResult {
  /// Creates a [GenUiCheckResult].
  const GenUiCheckResult({required this.isValid, required this.message});

  /// The result of the `checks` the renderer evaluated for a component, read
  /// from its resolved [props].
  ///
  /// The component's schema has to declare `checks` as a list of
  /// `CheckRule`s for the renderer to evaluate them; the generated schema of
  /// a widget with a `@GenUiChecked` parameter does.
  factory GenUiCheckResult.of(ComponentProps props) {
    if (props.isValid) return valid;
    return GenUiCheckResult(
      isValid: false,
      message: props.validationErrors.firstOrNull,
    );
  }

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
