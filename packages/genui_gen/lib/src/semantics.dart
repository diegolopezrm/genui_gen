import 'dart:convert';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';

/// One node of what a surface exposes to assistive technology, in the shape
/// A2UI's rendering cases are written in.
///
/// A rendered surface cannot be compared between Flutter, SwiftUI, Compose and
/// the web as pixels. It can be compared as semantics: every one of those
/// toolkits builds a tree of roles, names, values, states and actions, and
/// that is also the part of a rendered surface the protocol has opinions
/// about — a `Button` the agent labelled `Send` has to arrive as something
/// that says "Send" and can be pressed, whatever draws it.
class GenUiSemanticNode {
  /// Creates a [GenUiSemanticNode].
  const GenUiSemanticNode({
    required this.role,
    this.name = '',
    this.value = '',
    this.state = const <String, bool>{},
    this.actions = const <String>[],
  });

  /// Reads back a node written by [toJson].
  factory GenUiSemanticNode.fromJson(Map<String, Object?> json) =>
      GenUiSemanticNode(
        role: json['role'] as String? ?? 'group',
        name: json['name'] as String? ?? '',
        value: json['value'] as String? ?? '',
        state: <String, bool>{
          for (final entry
              in (json['state'] as Map<String, Object?>? ??
                      const <String, Object?>{})
                  .entries)
            entry.key: entry.value! as bool,
        },
        actions: <String>[
          for (final action in json['actions'] as List<Object?>? ?? const [])
            action! as String,
        ],
      );

  /// What kind of thing this is: `text`, `button`, `checkbox`, `switch`,
  /// `slider`, `text_field`, `image`, `link` or `group`.
  ///
  /// Deliberately a small set. It is the vocabulary every platform can be held
  /// to, not the union of what each one can express.
  final String role;

  /// What assistive technology announces this node as.
  final String name;

  /// What it currently holds, for the components that hold something.
  final String value;

  /// `checked`, `selected` and `disabled`, when the node has them.
  final Map<String, bool> state;

  /// What a user can do to it: `tap`, `increase`, `decrease`, and the rest of
  /// the platform's action names.
  final List<String> actions;

  /// This node as JSON, omitting what it does not carry so that a golden file
  /// stays readable.
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    if (name.isNotEmpty) 'name': name,
    if (value.isNotEmpty) 'value': value,
    if (state.isNotEmpty) 'state': state,
    if (actions.isNotEmpty) 'actions': actions,
  };

  @override
  String toString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is GenUiSemanticNode &&
      other.role == role &&
      other.name == name &&
      other.value == value &&
      _sameState(other.state) &&
      _sameActions(other.actions);

  @override
  int get hashCode => Object.hash(
    role,
    name,
    value,
    Object.hashAllUnordered(
      state.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(actions),
  );

  bool _sameState(Map<String, bool> other) =>
      other.length == state.length &&
      state.entries.every((entry) => other[entry.key] == entry.value);

  bool _sameActions(List<String> other) =>
      other.length == actions.length &&
      List<int>.generate(
        actions.length,
        (i) => i,
      ).every((i) => other[i] == actions[i]);
}

/// The meaningful part of [root], in traversal order.
///
/// Nodes a platform adds to lay things out carry no name, value, role or
/// action; they differ between platforms for reasons that have nothing to do
/// with the surface, and are left out. What remains is what a screen reader
/// user actually moves through.
List<GenUiSemanticNode> genUiSemantics(SemanticsNode root) {
  final result = <GenUiSemanticNode>[];

  void walk(SemanticsNode node) {
    final SemanticsData data = node.getSemanticsData();
    final List<String> actions = <String>[
      for (final action in SemanticsAction.values)
        if (data.hasAction(action)) action.name,
    ];
    final String role = _roleOf(data);
    final bool carriesMeaning =
        data.label.isNotEmpty ||
        data.value.isNotEmpty ||
        role != 'group' ||
        actions.isNotEmpty;
    if (carriesMeaning) {
      result.add(
        GenUiSemanticNode(
          role: role,
          name: data.label,
          value: data.value,
          state: _stateOf(data),
          actions: actions,
        ),
      );
    }
    node.visitChildren((SemanticsNode child) {
      // A merged child is already part of the node above it; counting it twice
      // would report two stops where a user finds one.
      if (!child.isMergedIntoParent) walk(child);
      return true;
    });
  }

  walk(root);
  return result;
}

String _roleOf(SemanticsData data) {
  final SemanticsFlags flags = data.flagsCollection;
  if (flags.isButton) return 'button';
  if (flags.isTextField) return 'text_field';
  if (flags.isSlider) return 'slider';
  if (flags.isImage) return 'image';
  if (flags.isLink) return 'link';
  if (flags.isChecked != CheckedState.none) return 'checkbox';
  if (flags.isToggled != Tristate.none) return 'switch';
  if (data.label.isNotEmpty) return 'text';
  return 'group';
}

Map<String, bool> _stateOf(SemanticsData data) {
  final SemanticsFlags flags = data.flagsCollection;
  return <String, bool>{
    if (flags.isChecked != CheckedState.none)
      'checked': flags.isChecked == CheckedState.isTrue,
    if (flags.isToggled != Tristate.none)
      'on': flags.isToggled == Tristate.isTrue,
    if (flags.isSelected != Tristate.none)
      'selected': flags.isSelected == Tristate.isTrue,
    if (flags.isEnabled != Tristate.none)
      'disabled': flags.isEnabled != Tristate.isTrue,
  };
}

/// Describes how [actual] differs from [expected], or `null` when it does not.
///
/// Written to be read in a failure message: one line per position, the
/// expected node above the one that arrived.
String? genUiSemanticsDiff(
  List<GenUiSemanticNode> expected,
  List<GenUiSemanticNode> actual,
) {
  if (expected.length == actual.length &&
      List<int>.generate(
        expected.length,
        (i) => i,
      ).every((i) => expected[i] == actual[i])) {
    return null;
  }

  final out = StringBuffer();
  for (var i = 0; i < expected.length || i < actual.length; i++) {
    final GenUiSemanticNode? want = i < expected.length ? expected[i] : null;
    final GenUiSemanticNode? got = i < actual.length ? actual[i] : null;
    if (want == got) continue;
    out
      ..writeln('  [$i] expected ${want ?? '(nothing)'}')
      ..writeln('      actual   ${got ?? '(nothing)'}');
  }
  return out.toString();
}

/// The meaningful semantics of what is currently on screen.
///
/// The no-argument form of [genUiSemantics], for a test that has just pumped
/// a widget and turned semantics on. Reads the view's own tree rather than a
/// node the caller has to dig out of the binding.
///
/// ```dart
/// final handle = tester.ensureSemantics();
/// await tester.pumpWidget(...);
/// await tester.pumpAndSettle();
/// final nodes = genUiRenderedSemantics();
/// handle.dispose();
/// ```
///
/// Throws a [StateError] when semantics are off, which in a widget test means
/// `tester.ensureSemantics()` was not called.
List<GenUiSemanticNode> genUiRenderedSemantics() {
  for (final RenderView view in RendererBinding.instance.renderViews) {
    final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) return genUiSemantics(root);
  }
  throw StateError(
    'No semantics tree was built. In a widget test, call '
    '`tester.ensureSemantics()` before pumping, and dispose the handle '
    'afterwards.',
  );
}
