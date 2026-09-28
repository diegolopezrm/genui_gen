import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// What a component's validation checks say about it right now.
///
/// A2UI's `CheckRule` carries a condition and the message to show when it
/// fails, and both are required. genui's own `checksToExpression` combines the
/// conditions into a single `and` and keeps no messages, so the basic catalog
/// can only colour a field red. Evaluating the rules one at a time costs
/// nothing more and keeps the sentence the agent wrote for the person reading
/// the screen.
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

/// Evaluates a component's `checks` and rebuilds when the answer changes.
///
/// [checks] is the raw value of the component's `checks` property, a list of
/// `{"condition": ..., "message": ...}` objects the agent sent. Anything else,
/// including `null` and an empty list, builds once with
/// [GenUiCheckResult.valid].
///
/// Each condition is a `DynamicBoolean`, so it resolves through the same
/// machinery as any other bound value and re-evaluates when the data model
/// changes underneath it.
class GenUiChecks extends StatefulWidget {
  /// Creates a [GenUiChecks].
  const GenUiChecks({
    super.key,
    required this.dataContext,
    required this.checks,
    required this.builder,
  });

  /// The context the conditions resolve against.
  final DataContext dataContext;

  /// The raw `checks` property from the component's data.
  final Object? checks;

  /// Called with the current result.
  final Widget Function(BuildContext context, GenUiCheckResult result) builder;

  @override
  State<GenUiChecks> createState() => _GenUiChecksState();
}

class _GenUiChecksState extends State<GenUiChecks> {
  final List<StreamSubscription<bool>> _subscriptions =
      <StreamSubscription<bool>>[];
  List<_Rule> _rules = const <_Rule>[];
  List<bool?> _passing = const <bool?>[];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(GenUiChecks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checks != widget.checks ||
        oldWidget.dataContext != widget.dataContext) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _rules = _rulesOf(widget.checks);
    _passing = List<bool?>.filled(_rules.length, null);
    for (var i = 0; i < _rules.length; i++) {
      final int index = i;
      _subscriptions.add(
        widget.dataContext
            .evaluateConditionStream(_rules[index].condition)
            .listen(
              (bool value) {
                if (!mounted || _passing[index] == value) return;
                setState(() => _passing[index] = value);
              },
              // A condition the agent wrote wrongly must not take the screen
              // down with it. It counts as passing and the component renders.
              onError: (Object _) {
                if (!mounted || _passing[index] == true) return;
                setState(() => _passing[index] = true);
              },
            ),
      );
    }
  }

  void _unsubscribe() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
    for (var i = 0; i < _rules.length; i++) {
      if (_passing[i] == false) {
        return widget.builder(
          context,
          GenUiCheckResult(isValid: false, message: _rules[i].message),
        );
      }
    }
    return widget.builder(context, GenUiCheckResult.valid);
  }
}

/// One `{"condition": ..., "message": ...}` the agent sent.
@immutable
class _Rule {
  const _Rule(this.condition, this.message);

  final Object? condition;
  final String message;
}

/// Reads the rules out of a raw `checks` value, skipping anything malformed.
///
/// A rule with no message is skipped rather than shown as an unexplained
/// failure: the spec requires one, and a red field with nothing to read is
/// worse than no check at all.
List<_Rule> _rulesOf(Object? checks) {
  if (checks is! List) return const <_Rule>[];
  return <_Rule>[
    for (final Object? entry in checks)
      if (entry is Map &&
          entry.containsKey('condition') &&
          entry['message'] is String)
        _Rule(entry['condition'], entry['message'] as String),
  ];
}
