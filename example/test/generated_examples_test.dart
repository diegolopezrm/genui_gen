// Every generated item claims its example composes against its own schema.
// This checks the claim rather than assuming it: the processor validates each
// component of a message against the catalog before applying it, and with
// `ValidationConfig.strict` it also requires a root and child references that
// resolve.
//
// Only the generated items are validated. The basic catalog is in the catalog
// under test — a generated example composes the basic `Text` for its child
// components — but its components carry no examples.
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  final List<CatalogItem> generated = exampleCatalog.components.values
      .whereType<CatalogItem>()
      .toList();

  group('generated examples', () {
    test('the app registers its generated items', () {
      expect(
        generated.map((CatalogItem item) => item.name),
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

    for (final CatalogItem item in generated) {
      test('${item.name} validates against the catalog schema', () {
        final String version = A2uiProtocolVersion.v0_9.jsonValue;
        for (var i = 0; i < item.exampleData.length; i++) {
          final processor = MessageProcessor<ComponentImplementation>(
            catalogs: [exampleCatalog],
            validationConfig: ValidationConfig.strict,
            reportErrorsOnly: true,
          );
          addTearDown(processor.dispose);

          final List<ErrorMessage> errors = processor.processMessagesWithErrors(
            [
              {
                'version': version,
                'createSurface': {
                  'surfaceId': 's',
                  'catalogId': exampleCatalog.id,
                },
              },
              {
                'version': version,
                'updateComponents': {
                  'surfaceId': 's',
                  'components': jsonDecode(item.exampleData[i]()),
                },
              },
            ],
          );

          expect(
            errors,
            isEmpty,
            reason: errors
                .map((ErrorMessage e) => jsonEncode(e.toJson()))
                .join('\n'),
          );
        }
      });
    }
  });
}
