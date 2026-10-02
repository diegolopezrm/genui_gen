import 'package:flutter/material.dart';
import 'package:genui_gen/genui_gen.dart';

part 'labeled_field.genui.dart';

/// A text input that writes what the user types and says why it is wrong.
///
/// Two halves of the protocol meet here. `@GenUiWrites` sends the value back
/// to the path the agent bound it to, and `@GenUiChecked` brings back what the
/// agent's own rules say about it. Neither the rules nor the message live in
/// this file: the agent wrote both, and the widget only has to show them.
@GenUiWidget(
  description:
      'A labelled text input. Bind `value` to a data path and the field '
      'writes what the user types there. Attach `checks` and the message of '
      'the first failing rule is shown under the field.',
)
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    @GenUiWrites('value') this.onChanged,
    @GenUiChecked() this.error,
  });

  /// The caption above the field.
  final String label;

  /// What the field currently holds.
  final String value;

  /// Called with the new text as the user types.
  final ValueChanged<String>? onChanged;

  /// The message of the first failing rule, or null while all of them pass.
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
