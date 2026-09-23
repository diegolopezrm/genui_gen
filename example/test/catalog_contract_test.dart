// Whether the last change broke the contract with the model.
//
// A catalog is a promise to something that cannot be recompiled: the agent's
// prompt and its few-shot examples describe the components as they were. This
// compares the catalog.json checked in beside it with the one the code
// produces now, and fails when a change would make a message the agent still
// knows how to write wrong.

import 'dart:convert';
import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';

void main() {
  test('the catalog has not broken the agent', () {
    final published =
        jsonDecode(File('catalog.json').readAsStringSync())
            as Map<String, Object?>;

    final changes = genUiCatalogDiff(
      published,
      genUiCatalogJson(
        exampleCatalog,
        title: 'genui_gen example catalog',
        description: 'The widgets this example app renders for an agent.',
      ),
    );

    expect(
      changes.where((change) => change.isBreaking),
      isEmpty,
      reason:
          '${changes.join('\n')}\n\n'
          'Regenerate catalog.json and review the diff if this is the change '
          'you meant to make.',
    );
  });

  test('the catalog is worth what it costs to send', () {
    final weight = genUiCatalogWeight(genUiCatalogJson(exampleCatalog));

    printOnFailure(weight.describe());
    // No component should be able to take over the prompt on its own.
    expect(
      weight.byComponent.keys.first,
      isNotNull,
      reason: weight.describe(),
    );
    expect(weight.shareOf(weight.byComponent.keys.first), lessThan(0.5));
  });
}
