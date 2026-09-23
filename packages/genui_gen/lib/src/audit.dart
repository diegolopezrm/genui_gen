import 'dart:convert';

import 'semantics.dart';

/// Something a recorded catalog exposes that a person using assistive
/// technology cannot work with.
enum GenUiAuditRule {
  /// A node a user can operate that has nothing to announce.
  ///
  /// A screen reader reads it as "button", and nothing else. This is the
  /// finding worth failing a build over: the control exists, it works, and
  /// nobody can tell what it does.
  unnamedControl,

  /// A node that carries a role but no name: an image, a field, a slider that
  /// announces its type and nothing about itself.
  unnamedNode,

  /// A component that reaches assistive technology as nothing at all.
  ///
  /// Either it is decoration, in which case this is correct and worth
  /// silencing, or the model can put something on screen that no screen reader
  /// will ever mention.
  exposesNothing,

  /// Two controls of the same component that announce themselves identically.
  ///
  /// A user hears "Delete, button" twice and has no way to tell which row they
  /// are on.
  ambiguousControls,
}

/// One thing the audit found.
class GenUiAuditFinding {
  /// Creates a [GenUiAuditFinding].
  const GenUiAuditFinding(this.rule, {required this.component, this.detail});

  /// Which rule it breaks.
  final GenUiAuditRule rule;

  /// The component it was found in.
  final String component;

  /// What was found, when the rule alone does not say it.
  final String? detail;

  @override
  String toString() =>
      '$component: ${rule.name}${detail == null ? '' : ' ($detail)'}';
}

/// Reads a recording made by [genUiSemantics] and reports what a person using
/// a screen reader could not work with.
///
/// Written to run over the same recording the golden test keeps, so a catalog
/// gets its accessibility checked by the file it already has rather than by a
/// second pass nobody remembers to run.
///
/// ```dart
/// final findings = genUiSemanticsAudit(recorded);
/// expect(findings, isEmpty, reason: findings.join('\n'));
/// ```
///
/// [allowEmpty] names the components that are decoration and are meant to
/// expose nothing, so that the rule stays sharp for every other component.
List<GenUiAuditFinding> genUiSemanticsAudit(
  Map<String, List<GenUiSemanticNode>> recorded, {
  Set<String> allowEmpty = const <String>{},
}) {
  final findings = <GenUiAuditFinding>[];

  for (final entry in recorded.entries) {
    final String component = entry.key;
    final List<GenUiSemanticNode> nodes = entry.value;

    if (nodes.isEmpty) {
      if (!allowEmpty.contains(component)) {
        findings.add(
          GenUiAuditFinding(
            GenUiAuditRule.exposesNothing,
            component: component,
          ),
        );
      }
      continue;
    }

    final controlNames = <String>[];
    for (final node in nodes) {
      final bool operable = node.actions.any(_operableActions.contains);
      // A tooltip counts as a name here. It is weaker than one — Android
      // announces it, other platforms are less reliable — and the recording
      // shows which of the two a control has, so the distinction stays
      // visible without failing a build over it.
      if (node.name.isEmpty && node.tooltip.isEmpty) {
        if (operable) {
          findings.add(
            GenUiAuditFinding(
              GenUiAuditRule.unnamedControl,
              component: component,
              detail: node.role,
            ),
          );
        } else if (node.role != 'text' && node.role != 'group') {
          findings.add(
            GenUiAuditFinding(
              GenUiAuditRule.unnamedNode,
              component: component,
              detail: node.role,
            ),
          );
        }
      } else if (operable) {
        controlNames.add(node.name.isEmpty ? node.tooltip : node.name);
      }
    }

    final seen = <String>{};
    for (final name in controlNames) {
      if (!seen.add(name)) {
        findings.add(
          GenUiAuditFinding(
            GenUiAuditRule.ambiguousControls,
            component: component,
            detail: name,
          ),
        );
      }
    }
  }

  return findings;
}

const Set<String> _operableActions = <String>{
  'tap',
  'longPress',
  'increase',
  'decrease',
  'setText',
  'dismiss',
};

/// How much of every prompt one component takes up.
///
/// A catalog is sent to the model on every request. Nobody measures it,
/// because nothing makes it visible: the schema is generated, the prompt is
/// assembled somewhere else, and the bill arrives monthly. This puts a number
/// on each component, in the characters its schema occupies, so the three
/// components that take half the prompt can be found and argued about.
///
/// Characters rather than tokens on purpose. Tokens depend on the model doing
/// the counting, and a number that pretends to be exact about someone else's
/// tokenizer is worse than a proportional one that is honest.
class GenUiCatalogWeight {
  /// Creates a [GenUiCatalogWeight].
  const GenUiCatalogWeight({
    required this.total,
    required this.byComponent,
    required this.shared,
  });

  /// The size of the whole document.
  final int total;

  /// The size of each component's own schema, largest first.
  final Map<String, int> byComponent;

  /// What is left: the shared definitions, the functions, the envelope.
  final int shared;

  /// The share of the document one component takes, from 0 to 1.
  double shareOf(String component) =>
      total == 0 ? 0 : (byComponent[component] ?? 0) / total;

  /// A table, largest first, for a test that prints it or a CI job that keeps
  /// it in the log.
  String describe() {
    final buffer = StringBuffer('$total characters in total\n');
    for (final entry in byComponent.entries) {
      final String share = (shareOf(entry.key) * 100).toStringAsFixed(1);
      buffer.writeln(
        '  ${entry.value.toString().padLeft(7)}  $share%  ${entry.key}',
      );
    }
    buffer.writeln(
      '  ${shared.toString().padLeft(7)}  '
      '${(total == 0 ? 0 : shared / total * 100).toStringAsFixed(1)}%  '
      '(shared definitions)',
    );
    return buffer.toString();
  }
}

/// Measures what [catalogJson] costs, component by component.
///
/// [catalogJson] is the document `genUiCatalogJson` produces.
GenUiCatalogWeight genUiCatalogWeight(Map<String, Object?> catalogJson) {
  const encoder = JsonEncoder();
  final int total = encoder.convert(catalogJson).length;
  final Map<String, Object?> components =
      (catalogJson['components'] as Map?)?.cast<String, Object?>() ??
      const <String, Object?>{};

  final entries = <String, int>{
    for (final entry in components.entries)
      entry.key: encoder.convert(entry.value).length,
  };
  final sorted = entries.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final int componentTotal = entries.values.fold(0, (sum, size) => sum + size);
  return GenUiCatalogWeight(
    total: total,
    byComponent: <String, int>{
      for (final entry in sorted) entry.key: entry.value,
    },
    shared: total - componentTotal,
  );
}
