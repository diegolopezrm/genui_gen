// Every generated component claims its example composes against its own
// schema. This checks the claim rather than assuming it: each example goes
// through a message processor with a strict validation config, which checks
// every component against the catalog's schema and the surface as a graph,
// as an agent's message would be checked.
//
// Only the generated components carry examples; the basic ones are in the
// catalog under test because an example composes the basic `Text` for its
// child components.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:example/genui_catalog.g.dart';
import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  group('generated examples', () {
    test('the app registers its generated components', () {
      expect(
        genUiCatalogItems.map((GenUiComponent c) => c.name),
        containsAll(<String>[
          'ProductCard',
          'StatTile',
          'TagRow',
          'Panel',
          'MetricsTable',
          'PreferenceRow',
        ]),
      );
    });

    for (final GenUiComponent component in genUiCatalogItems) {
      test('${component.name} validates against the catalog schema', () {
        for (final String example in component.examples) {
          final processor = MessageProcessor<ComponentImplementation>(
            catalogs: [exampleCatalog],
            defaultVersion: A2uiProtocolVersion.v0_9,
            validationConfig: ValidationConfig.strict,
          );
          addTearDown(processor.dispose);
          expect(
            () => processor.processMessages(<Object?>[
              {
                'version': 'v0.9',
                'createSurface': {
                  'surfaceId': 'example',
                  'catalogId': exampleCatalog.id,
                },
              },
              {
                'version': 'v0.9',
                'updateComponents': {
                  'surfaceId': 'example',
                  'components': jsonDecode(example),
                },
              },
            ]),
            returnsNormally,
            reason: example,
          );
        }
      });
    }
  });
}
