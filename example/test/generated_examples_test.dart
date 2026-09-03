// Every generated item claims its example composes against its own schema.
// This checks the claim rather than assuming it: genui's own
// `validateCatalogItemExamples` parses each example and resolves it against
// `A2uiSchemas.updateComponentsSchema` for the whole catalog.
//
// Only the generated items are validated. The basic catalog is in the catalog
// under test — a generated example composes genui's `Text` for its child
// components — but validating genui's own items here would just be slow.
import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui/test.dart';

void main() {
  final Set<String> basicNames = BasicCatalogItems.asCatalog().items
      .map((CatalogItem item) => item.name)
      .toSet();
  final List<CatalogItem> generated = exampleCatalog.items
      .where((CatalogItem item) => !basicNames.contains(item.name))
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
        ]),
      );
    });

    for (final CatalogItem item in generated) {
      test('${item.name} validates against the catalog schema', () async {
        final List<ExampleValidationError> errors =
            await validateCatalogItemExamples(item, exampleCatalog);
        expect(
          errors,
          isEmpty,
          reason: errors
              .map((ExampleValidationError e) => e.toString())
              .join('\n'),
        );
      });
    }
  });
}
