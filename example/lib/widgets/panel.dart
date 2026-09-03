import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'panel.genui.dart';

/// A titled container with a body, optional trailing actions and a close
/// button.
@GenUiWidget(
  description:
      'A titled panel that wraps any other component. It has a header with '
      'the title and a close button, a body and an optional row of action '
      'components (typically buttons) along the bottom edge. Use it to group '
      'related content under a heading.',
)
class Panel extends StatelessWidget {
  /// Creates a panel.
  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    @GenUiAction(eventName: 'panel_closed') this.onClose,
  });

  /// The heading shown at the top of the panel.
  final String title;

  /// The component rendered as the body of the panel.
  final Widget child;

  /// Components laid out along the bottom edge, usually buttons.
  final List<Widget> actions;

  /// Fired when the user presses the close button in the header.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
              ],
            ),
            const Divider(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: child,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
