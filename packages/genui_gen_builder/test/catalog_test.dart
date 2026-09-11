import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:genui_gen_builder/builder.dart';
import 'package:test/test.dart';

import 'src/harness.dart';

/// Runs the aggregating builder over already-generated `.genui.dart` files.
///
/// The per-library generator is not involved: this builder reads its output,
/// so the test provides that output directly.
Future<String?> aggregate(
  Map<String, String> parts, {
  List<String>? warnings,
  List<String>? errors,
}) async {
  final result = await testBuilder(
    genUiCatalogBuilder(const BuilderOptions({})),
    {...parts},
    rootPackage: 'a',
    onLog: (record) {
      if (record.level.value >= 1000) {
        errors?.add('${record.message}${record.error ?? ''}');
      } else if (record.level.value >= 900) {
        warnings?.add(record.message);
      }
    },
  );
  final reader = result.readerWriter.testing;
  // `build_to: source` writes into `lib/` in a real build; under `testBuilder`
  // the output lands in the generated tree instead, the same fallback
  // `generateRaw` makes in `src/harness.dart`.
  const sourceId = 'lib/genui_catalog.g.dart';
  const generatedId = '.dart_tool/build/generated/a/lib/genui_catalog.g.dart';
  for (final path in [sourceId, generatedId]) {
    final id = AssetId('a', path);
    if (reader.exists(id)) return reader.readString(id);
  }
  return null;
}

String part(List<String> names) => [
  '// GENERATED CODE - DO NOT MODIFY BY HAND',
  for (final name in names) 'final CatalogItem $name = CatalogItem();',
].join('\n');

void main() {
  test('collects every item in the package', () async {
    final out = await aggregate({
      'a|lib/widgets/card.genui.dart': part(['productCardCatalogItem']),
      'a|lib/widgets/tile.genui.dart': part(['statTileCatalogItem']),
    });

    expect(out, isNotNull);
    expect(normalize(out!), contains("import 'package:genui/genui.dart';"));
    expect(normalize(out), contains("import 'widgets/card.dart';"));
    expect(normalize(out), contains("import 'widgets/tile.dart';"));
    expect(
      normalize(out),
      contains(
        'final List<CatalogItem> genUiCatalogItems = <CatalogItem>['
        'productCardCatalogItem, statTileCatalogItem]',
      ),
    );
  });

  test('one file may declare more than one item', () async {
    final out = await aggregate({
      'a|lib/pair.genui.dart': part(['oneCatalogItem', 'twoCatalogItem']),
    });

    expect(normalize(out!), contains('[oneCatalogItem, twoCatalogItem]'));
    // One import, not one per item.
    expect("'pair.dart'".allMatches(out).length, 1);
  });

  test('the order does not depend on where the files are', () async {
    final first = await aggregate({
      'a|lib/z.genui.dart': part(['alphaCatalogItem']),
      'a|lib/a.genui.dart': part(['zuluCatalogItem']),
    });
    final second = await aggregate({
      'a|lib/a.genui.dart': part(['zuluCatalogItem']),
      'a|lib/z.genui.dart': part(['alphaCatalogItem']),
    });

    expect(normalize(first!), contains('[alphaCatalogItem, zuluCatalogItem]'));
    expect(first, second);
  });

  test('a file with no catalog items contributes nothing', () async {
    final out = await aggregate({
      'a|lib/only_data.genui.dart':
          'final ObjectSchema rowGenUiSchema = ObjectSchema();\n'
          'Row rowFromGenUiJson(Map<String, Object?> json) => Row();',
      'a|lib/card.genui.dart': part(['cardCatalogItem']),
    });

    expect(normalize(out!), contains('[cardCatalogItem]'));
    expect(out, isNot(contains('only_data.dart')));
  });

  test('a package with nothing annotated gets no file', () async {
    final out = await aggregate({'a|lib/plain.dart': 'class Plain {}'});

    expect(out, isNull);
  });

  test('a private item is skipped, and said so', () async {
    final warnings = <String>[];
    final out = await aggregate({
      'a|lib/card.genui.dart': part(['_hiddenCatalogItem', 'cardCatalogItem']),
    }, warnings: warnings);

    expect(normalize(out!), contains('[cardCatalogItem]'));
    expect(out, isNot(contains('_hiddenCatalogItem')));
    expect(
      warnings.join('\n'),
      allOf(
        contains('_hiddenCatalogItem'),
        contains('the variable is private'),
      ),
    );
  });

  test('two files that generate the same name are rejected', () async {
    final errors = <String>[];
    await aggregate({
      'a|lib/one.genui.dart': part(['cardCatalogItem']),
      'a|lib/two.genui.dart': part(['cardCatalogItem']),
    }, errors: errors);

    expect(
      errors.join('\n'),
      allOf(
        contains('lib/one.genui.dart'),
        contains('lib/two.genui.dart'),
        contains('cardCatalogItem'),
      ),
    );
  });
}
