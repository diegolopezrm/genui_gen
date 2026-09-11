import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'preference_row.genui.dart';

/// A single preference the user can turn on or off.
///
/// The switch is what makes this one interesting: `onChanged` is annotated
/// `@GenUiWrites('enabled')`, so flipping it writes the new state into the
/// surface's data model at whatever path the model bound `enabled` to. Bind it
/// to `/settings/notifications` and the agent can read the answer back from
/// there; send a literal and the value still round-trips, through a path the
/// component owns.
@GenUiWidget(
  description:
      'One preference the user can turn on or off, with a label and an '
      'optional line of explanation. Use it when you need the user to answer '
      'yes or no and you want to read the answer back: bind `enabled` to a '
      'data path, and the switch writes the new state there.',
)
class PreferenceRow extends StatelessWidget {
  /// Creates a preference row.
  const PreferenceRow({
    super.key,
    required this.label,
    required this.enabled,
    this.detail,
    @GenUiWrites('enabled') this.onChanged,
  });

  /// A short caption naming the preference, e.g. "Weekly summary".
  final String label;

  /// Whether the preference is currently on.
  final bool enabled;

  /// One line of explanation shown under the label.
  final String? detail;

  /// Called with the new state when the user flips the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: SwitchListTile(
        value: enabled,
        onChanged: onChanged,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: detail == null
            ? null
            : Text(
                detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
