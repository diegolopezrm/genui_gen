import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

const _button = GenUiSemanticNode(
  role: 'button',
  name: 'Confirm',
  actions: ['tap'],
);
const _unnamedButton = GenUiSemanticNode(role: 'button', actions: ['tap']);
const _text = GenUiSemanticNode(role: 'text', name: 'Total');
const _unnamedImage = GenUiSemanticNode(role: 'image');

void main() {
  group('genUiSemanticsAudit', () {
    test('says nothing about a catalog that behaves', () {
      expect(
        genUiSemanticsAudit({
          'Card': [_text, _button],
        }),
        isEmpty,
      );
    });

    test('reports a control nobody can identify', () {
      final findings = genUiSemanticsAudit({
        'Player': [_unnamedButton],
      });

      expect(findings.single.rule, GenUiAuditRule.unnamedControl);
      expect(findings.single.component, 'Player');
      expect(findings.single.detail, 'button');
    });

    test('reports a node with a role and no name', () {
      final findings = genUiSemanticsAudit({
        'Gallery': [_unnamedImage],
      });

      expect(findings.single.rule, GenUiAuditRule.unnamedNode);
    });

    test('reports a component that exposes nothing', () {
      final findings = genUiSemanticsAudit({'Divider': []});

      expect(findings.single.rule, GenUiAuditRule.exposesNothing);
    });

    test('stays quiet about decoration that was declared as such', () {
      expect(
        genUiSemanticsAudit({'Divider': []}, allowEmpty: {'Divider'}),
        isEmpty,
      );
    });

    test('reports two controls that announce themselves the same', () {
      final findings = genUiSemanticsAudit({
        'Row': [_button, _text, _button],
      });

      expect(findings.single.rule, GenUiAuditRule.ambiguousControls);
      expect(findings.single.detail, 'Confirm');
    });

    test('does not mistake an unnamed group for a problem', () {
      expect(
        genUiSemanticsAudit({
          'Column': [const GenUiSemanticNode(role: 'group'), _text],
        }),
        isEmpty,
      );
    });
  });

  group('genUiCatalogWeight', () {
    Map<String, Object?> catalogOf(Map<String, String> descriptions) =>
        genUiCatalogJson(
          Catalog([
            for (final entry in descriptions.entries)
              CatalogItem(
                name: entry.key,
                dataSchema: S.object(
                  description: 'A component.',
                  properties: {'text': S.string(description: entry.value)},
                ),
                widgetBuilder: (ctx) => const SizedBox.shrink(),
              ),
          ], catalogId: 'dev.dlsoft.test'),
        );

    test('puts the heaviest component first', () {
      final weight = genUiCatalogWeight(
        catalogOf({'Small': 'A.', 'Large': 'A much longer description. ' * 20}),
      );

      expect(weight.byComponent.keys.first, 'Large');
      expect(weight.shareOf('Large'), greaterThan(weight.shareOf('Small')));
    });

    test('accounts for what is not a component', () {
      final weight = genUiCatalogWeight(catalogOf({'One': 'A.'}));

      expect(weight.shared, greaterThan(0));
      expect(
        weight.byComponent.values.fold(0, (sum, size) => sum + size) +
            weight.shared,
        weight.total,
      );
    });

    test('describes itself as a table', () {
      final description = genUiCatalogWeight(
        catalogOf({'One': 'A.'}),
      ).describe();

      expect(description, contains('characters in total'));
      expect(description, contains('One'));
      expect(description, contains('shared definitions'));
    });
  });
}
