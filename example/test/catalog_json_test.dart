import 'dart:io';

import 'package:example/genui_catalog.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

/// Keeps `catalog.json` — the document an agent reads to learn what it may
/// ask this app for — in step with the annotated widgets.
///
/// The file is checked in so that a reviewer sees what a new `@GenUiWidget`
/// exposed to the model, which is the part of a change nobody can see from the
/// Dart diff alone. Regenerate it with:
///
/// ```sh
/// flutter test test/catalog_json_test.dart --update-goldens
/// ```
void main() {
  test('catalog.json describes the generated catalog', () {
    final file = File('catalog.json');
    final json = genUiCatalogJsonString(
      genUiCatalog,
      title: 'genui_gen example catalog',
      description: 'The widgets this example app renders for an agent.',
    );

    if (autoUpdateGoldenFiles) file.writeAsStringSync('$json\n');

    expect(
      file.readAsStringSync(),
      '$json\n',
      reason:
          'catalog.json is out of date. Regenerate it with '
          '`flutter test test/catalog_json_test.dart --update-goldens`.',
    );
  });

  test('every generated widget appears in it', () {
    final components =
        genUiCatalogJson(genUiCatalog)['components']! as Map<String, Object?>;

    expect(
      components.keys,
      containsAll(<String>[
        'MetricsTable',
        'Panel',
        'PreferenceRow',
        'ProductCard',
        'StatTile',
        'TagRow',
      ]),
    );
  });
}
