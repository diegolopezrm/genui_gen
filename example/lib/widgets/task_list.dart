import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'task_list.genui.dart';

/// A list whose rows the agent describes once and the data model repeats.
///
/// `rows` is marked `template: true`, so the model may either name the rows
/// one by one or send `{"componentId": "task_row", "path": "/tasks"}` and let
/// the data decide how many there are. The second is what makes the list grow
/// when new tasks arrive without the agent composing a new surface.
@GenUiWidget(description: 'A titled list of rows, one per item in the data.')
class TaskList extends StatelessWidget {
  const TaskList({
    super.key,
    required this.title,
    @GenUiProp(template: true) required this.rows,
    this.emptyLabel = 'Nothing here yet.',
  });

  /// The heading above the list.
  final String title;

  /// One row per task.
  final List<Widget> rows;

  /// Shown when there are no rows.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}
