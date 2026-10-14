import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

GenUiComponent _component(String name, List<String> examples) => GenUiComponent(
  name: name,
  schema: GenUiSchemas.component(description: 'A $name.'),
  examples: examples,
  builder: (context, node, props, buildChild) => const SizedBox(),
);

void main() {
  group('genUiExampleInstructions', () {
    test('shows each example as compact JSON under its component', () {
      final String instructions = genUiExampleInstructions([
        _component('Card', ['[\n  {"id": "root", "component": "Card"}\n]']),
      ])!;

      expect(instructions, contains('`updateComponents`'));
      expect(instructions, contains('### Card'));
      expect(
        instructions,
        contains('```json\n[{"id":"root","component":"Card"}]\n```'),
      );
    });

    test('leaves out a component without examples', () {
      final GenUiComponent card = _component('Card', [
        jsonEncode([
          {'id': 'root', 'component': 'Card'},
        ]),
      ]);
      final ComponentImplementation plain = ComponentImplementation(
        name: 'Plain',
        schema: GenUiSchemas.component(description: 'Hand-written.'),
        builder: (context, node, props, buildChild) => const SizedBox(),
      );

      final String instructions = genUiExampleInstructions([
        plain,
        _component('Bare', const []),
        card,
      ])!;
      expect(instructions, isNot(contains('Plain')));
      expect(instructions, isNot(contains('Bare')));
      expect(instructions, contains('### Card'));
    });

    test('is null when there is nothing to show', () {
      expect(genUiExampleInstructions(const []), isNull);
      expect(genUiExampleInstructions([_component('Bare', const [])]), isNull);
    });

    test('travels in the catalog document', () {
      final CatalogImplementation catalog = CatalogImplementation(
        id: 'dev.dlsoft.test',
        components: [
          _component('Card', ['[{"id": "root", "component": "Card"}]']),
        ],
        instructions: genUiExampleInstructions([
          _component('Card', ['[{"id": "root", "component": "Card"}]']),
        ]),
      );

      expect(
        genUiCatalogJson(catalog)['instructions'],
        contains('"component":"Card"'),
      );
    });
  });
}
