import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'tag_row.genui.dart';

/// A horizontal, wrapping row of chips with one of them highlighted.
@GenUiWidget(
  description:
      'A row of short text tags rendered as chips. Exactly one tag is '
      'highlighted as selected. Use it to show categories, filters or '
      'keywords attached to an item.',
)
class TagRow extends StatelessWidget {
  /// Creates a tag row.
  const TagRow({super.key, required this.tags, this.selectedIndex = 0});

  /// The tags to display, one chip each, in order.
  final List<String> tags;

  /// The zero-based index of the highlighted tag. Defaults to the first one.
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (int index, String tag) in tags.indexed)
          ChoiceChip(
            label: Text(tag),
            selected: index == selectedIndex,
            onSelected: null,
          ),
      ],
    );
  }
}
