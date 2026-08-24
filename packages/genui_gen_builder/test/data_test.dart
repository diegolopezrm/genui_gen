import 'package:test/test.dart';

import 'src/harness.dart';

/// A `@GenUiData` class with two scalar fields, reused by several tests.
const badge = '''
@GenUiData(description: 'A small badge.')
class Badge {
  const Badge({required this.text, this.count = 0});

  /// Badge caption.
  final String text;
  final int count;
}
''';

/// A data class with one field of every scalar kind.
const row = '''
enum Trend { up, down }

@GenUiData()
class Row {
  const Row({
    required this.label,
    required this.value,
    required this.count,
    required this.rate,
    required this.ok,
    required this.trend,
    required this.tags,
  });
  final String label;
  final double value;
  final int count;
  final num rate;
  final bool ok;
  final Trend trend;
  final List<String> tags;
}
''';

void main() {
  group('data class declarations', () {
    test('schema and decoder are generated', () async {
      final out = await generate(badge);
      expect(out, contains('/// Generated schema for [Badge].'));
      expect(
        out,
        contains(
          'final ObjectSchema badgeGenUiSchema = ObjectSchema('
          "description: 'A small badge.', "
          "properties: {'text': S.string(description: 'Badge caption.'), "
          "'count': S.integer()}, "
          "required: ['text'])",
        ),
      );
      expect(
        out,
        contains('/// Decodes a [Badge] from the map the model produced.'),
      );
      expect(
        out,
        contains(
          'Badge badgeFromGenUiJson(Map<String, Object?> json, '
          '[GenUiMissingFieldReporter? onMissing]) => Badge('
          "text: genUiAsString(json['text']) ?? "
          "genUiMissingField<String>(onMissing, 'text', ''), "
          "count: genUiAsNum(json['count'])?.toInt() ?? 0)",
        ),
      );
    });

    test('fields use plain S.* schemas, never A2uiSchemas', () async {
      final out = await generate(row);
      expect(out, isNot(contains('A2uiSchemas')));
      expect(out, contains("'label': S.string()"));
      expect(out, contains("'value': S.number()"));
      expect(out, contains("'count': S.integer()"));
      expect(out, contains("'rate': S.number()"));
      expect(out, contains("'ok': S.boolean()"));
      expect(out, contains("'trend': S.string(enumValues: ['up', 'down'])"));
      expect(out, contains("'tags': S.list(items: S.string())"));
      expect(
        out,
        contains(
          "required: ['label', 'value', 'count', 'rate', 'ok', 'trend', "
          "'tags']",
        ),
      );
    });

    test('required fields fall back to neutral values', () async {
      final out = await generate(row);
      expect(
        out,
        contains(
          "label: genUiAsString(json['label']) ?? "
          "genUiMissingField<String>(onMissing, 'label', '')",
        ),
      );
      expect(
        out,
        contains(
          "value: (genUiAsNum(json['value']) ?? "
          "genUiMissingField<num>(onMissing, 'value', 0)) .toDouble()",
        ),
      );
      expect(
        out,
        contains(
          "count: (genUiAsNum(json['count']) ?? "
          "genUiMissingField<num>(onMissing, 'count', 0)) .toInt()",
        ),
      );
      expect(
        out,
        contains(
          "rate: genUiAsNum(json['rate']) ?? "
          "genUiMissingField<num>(onMissing, 'rate', 0)",
        ),
      );
      expect(
        out,
        contains(
          "ok: genUiAsBool(json['ok']) ?? "
          "genUiMissingField<bool>(onMissing, 'ok', false)",
        ),
      );
      expect(
        out,
        contains(
          "trend: Trend.values.asNameMap()[genUiAsString(json['trend'])] ?? "
          "genUiMissingField<Trend>(onMissing, 'trend', Trend.values.first)",
        ),
      );
      expect(
        out,
        contains(
          "tags: genUiAsStringList(json['tags']) ?? "
          "genUiMissingField<List<String>>(onMissing, 'tags', const <String>[])",
        ),
      );
    });

    test('optional fields stay nullable and defaults are reused', () async {
      final out = await generate('''
@GenUiData()
class Row {
  const Row({this.label, this.count = 7});
  final String? label;
  final int count;
}
''');
      expect(out, contains("label: genUiAsString(json['label'])"));
      expect(out, contains("count: genUiAsNum(json['count'])?.toInt() ?? 7"));
      expect(out, isNot(contains('required:')));
    });

    test('the description falls back to the class doc comment', () async {
      final out = await generate('''
/// One row of the table.
@GenUiData()
class Row {
  const Row({required this.label});
  final String label;
}
''');
      expect(
        out,
        contains("ObjectSchema(description: 'One row of the table.', "),
      );
    });

    test('@GenUiData(constructor:) picks a named constructor', () async {
      final out = await generate('''
@GenUiData(constructor: 'simple')
class Row {
  const Row.simple({required this.label}) : count = 0;
  const Row.full({required this.label, required this.count});
  final String label;
  final int count;
}
''');
      expect(
        out,
        contains(
          'Row rowFromGenUiJson(Map<String, Object?> json, '
          '[GenUiMissingFieldReporter? onMissing]) => Row.simple(',
        ),
      );
      expect(out, isNot(contains('count:')));
    });

    test('@GenUiProp renames, describes and ignores data fields', () async {
      final out = await generate('''
@GenUiData()
class Row {
  const Row({
    @GenUiProp(name: 'label', description: 'The caption.') required this.text,
    @GenUiProp(ignore: true) this.internal = 0,
  });
  final String text;
  final int internal;
}
''');
      expect(out, contains("'label': S.string(description: 'The caption.')"));
      expect(
        out,
        contains(
          "text: genUiAsString(json['label']) ?? "
          "genUiMissingField<String>(onMissing, 'label', '')",
        ),
      );
      expect(out, isNot(contains('internal')));
    });

    test('positional fields keep their position', () async {
      final out = await generate('''
@GenUiData()
class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;
}
''');
      expect(
        out,
        contains(
          'Point pointFromGenUiJson(Map<String, Object?> json, '
          '[GenUiMissingFieldReporter? onMissing]) => Point('
          "(genUiAsNum(json['x']) ?? "
          "genUiMissingField<num>(onMissing, 'x', 0)) .toDouble(), "
          "(genUiAsNum(json['y']) ?? "
          "genUiMissingField<num>(onMissing, 'y', 0)) .toDouble())",
        ),
      );
    });

    test('the generated names follow lowerCamel', () async {
      final out = await generate('''
@GenUiData()
class HTTPRow {
  const HTTPRow({required this.label});
  final String label;
}
''');
      expect(out, contains('final ObjectSchema httpRowGenUiSchema ='));
      expect(out, contains('HTTPRow httpRowFromGenUiJson('));
    });
  });

  group('nested data classes', () {
    test('the nested schema is inlined and decoded in turn', () async {
      final out = await generate('''
$badge

@GenUiData()
class Row {
  const Row({required this.label, this.badge, this.badges = const <Badge>[]});
  final String label;
  final Badge? badge;
  final List<Badge> badges;
}
''');
      expect(out, contains("'badge': badgeGenUiSchema"));
      expect(out, contains("'badges': S.list(items: badgeGenUiSchema)"));
      expect(
        out,
        contains(
          "badge: switch (genUiAsObject(json['badge'])) {"
          'final Map<String, Object?> nested => badgeFromGenUiJson(nested, '
          "genUiNestedField(onMissing, 'badge')), "
          '_ => null}',
        ),
      );
      expect(
        out,
        contains(
          "badges: genUiAsObjectList(json['badges']) ?.map((nested) => "
          "badgeFromGenUiJson(nested, genUiNestedField(onMissing, 'badges'))) "
          '.toList() ?? const <Badge>[]',
        ),
      );
      // The nested schema is inlined by reference, never through a `$ref`.
      expect(out, isNot(contains(r'$ref')));
    });

    test('a required nested object falls back to an empty map', () async {
      final out = await generate('''
$badge

@GenUiData()
class Row {
  const Row({required this.badge});
  final Badge badge;
}
''');
      expect(
        out,
        contains(
          "_ => genUiMissingField<Badge>(onMissing, 'badge', "
          'badgeFromGenUiJson(const <String, Object?>{}))',
        ),
      );
      expect(out, contains("required: ['badge']"));
    });
  });

  group('widget properties', () {
    test('a required object property binds, decodes and reports', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});
  final Badge badge;
}
''');
      expect(
        out,
        contains(
          "dataSchema: S.object(description: 'Shows a badge.', "
          "properties: {'badge': S.combined(oneOf: [badgeGenUiSchema, "
          'A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()])}, '
          "required: ['badge'])",
        ),
      );
      expect(out, contains("'badge': GenUiBinding.object(data['badge'])"));
      // The reporter is handed over only on the branch where the object
      // really resolved. The fallback branch decodes the empty map without
      // one, so a `{"path": ...}` that has not resolved yet produces the
      // single (and suppressed) `badge` report instead of one false
      // `badge.<field>` error per required field.
      expect(
        out,
        contains(
          "badge: switch (v.object('badge')) {"
          'final Map<String, Object?> json => '
          "badgeFromGenUiJson(json, missingIn('badge')), "
          '_ => badgeFromGenUiJson('
          "missing<JsonMap>('badge', const <String, Object?>{}))}",
        ),
      );
    });

    test('an optional object property resolves to null', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, this.badge});
  final Badge? badge;
}
''');
      expect(
        out,
        contains(
          "badge: switch (v.object('badge')) {"
          'final Map<String, Object?> json => '
          "badgeFromGenUiJson(json, missingIn('badge')), "
          '_ => null}',
        ),
      );
      expect(
        out,
        contains(
          "dataSchema: S.object(description: 'Shows a badge.', "
          "properties: {'badge': S.combined(oneOf: [badgeGenUiSchema, "
          'A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()])})',
        ),
      );
    });

    test('an object property with a default falls back to it', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, this.badge = const Badge(text: 'none')});
  final Badge badge;
}
''');
      expect(out, contains("_ => (const Badge(text: 'none'))}"));
    });

    test('a required list property maps the decoder and reports', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, required this.badges});
  final List<Badge> badges;
}
''');
      expect(
        out,
        contains(
          "'badges': A2uiSchemas.listOrReference(items: badgeGenUiSchema)",
        ),
      );
      expect(
        out,
        contains("'badges': GenUiBinding.objectList(data['badges'])"),
      );
      expect(
        out,
        contains(
          "badges: v .objectList('badges') ?.map((json) => "
          "badgeFromGenUiJson(json, missingIn('badges'))) .toList() ?? "
          "missing<List<Badge>>('badges', const <Badge>[])",
        ),
      );
    });

    test('an optional list property stays nullable', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, this.badges});
  final List<Badge>? badges;
}
''');
      expect(
        out,
        contains(
          "badges: v .objectList('badges') ?.map((json) => "
          "badgeFromGenUiJson(json, missingIn('badges'))) .toList())",
        ),
      );
      expect(out, isNot(contains('missing<')));
    });

    test('the property description is kept on a list property', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, required this.badges});

  /// The badges to show.
  final List<Badge> badges;
}
''');
      expect(
        out,
        contains(
          "'badges': A2uiSchemas.listOrReference("
          "description: 'The badges to show.', items: badgeGenUiSchema)",
        ),
      );
    });

    test('a use-site description overrides the class description', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});

  /// The badge shown next to the title.
  final Badge badge;
}
''');
      expect(
        out,
        contains(
          "'badge': S.combined(description: "
          "'The badge shown next to the title.', "
          'oneOf: [badgeGenUiSchema, A2uiSchemas.dataBindingSchema(), '
          'A2uiSchemas.functionCall()])',
        ),
      );
      // The class keeps its own description; only the property carries the
      // use-site one.
      expect(out, contains("ObjectSchema(description: 'A small badge.', "));
    });

    test(
      'an object property without a description stays a reference',
      () async {
        final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});
  final Badge badge;
}
''');
        expect(
          out,
          contains(
            "'badge': S.combined(oneOf: [badgeGenUiSchema, "
            'A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()])',
          ),
        );
        expect(out, isNot(contains('ObjectSchema.fromMap')));
      },
    );

    test('a nested data field keeps its own description', () async {
      final out = await generate('''
$badge

@GenUiData()
class Row {
  const Row({required this.label, required this.badge});
  final String label;

  /// The badge for this row.
  final Badge badge;
}

@GenUiWidget(description: 'A row.')
class RowView extends StatelessWidget {
  const RowView({super.key, required this.row});
  final Row row;
}
''');
      expect(
        out,
        contains(
          "'badge': ObjectSchema.fromMap({...badgeGenUiSchema.value, "
          "'description': 'The badge for this row.'})",
        ),
      );
    });

    test('data and 0.1 properties mix in one widget', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, required this.title, required this.badges});
  final String title;
  final List<Badge> badges;
}
''');
      expect(out, contains("'title': A2uiSchemas.stringReference()"));
      expect(
        out,
        contains(
          "'badges': A2uiSchemas.listOrReference(items: badgeGenUiSchema)",
        ),
      );
      expect(out, contains("'title': GenUiBinding.string(data['title'])"));
      expect(
        out,
        contains("'badges': GenUiBinding.objectList(data['badges'])"),
      );
    });
  });

  group('examples', () {
    test('an object property produces one sample object', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});
  final Badge badge;
}
''');
      expect(out, contains('"badge":{"text":"Sample text"}'));
    });

    test('a list property produces two sample objects', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, required this.badges});
  final List<Badge> badges;
}
''');
      expect(
        out,
        contains(
          '"badges":[{"text":"Sample text 1"},{"text":"Sample text 2"}]',
        ),
      );
    });

    test('numbers are spread across the entries of a list', () async {
      final out = await generate('''
@GenUiData()
class Point {
  const Point({required this.label, required this.x, required this.y});
  final String label;
  final int x;
  final double y;
}

@GenUiWidget(description: 'A chart.')
class Chart extends StatelessWidget {
  const Chart({super.key, required this.points, required this.origin});
  final List<Point> points;
  final Point origin;
}
''');
      // Entries of the list vary so the model does not see one repeated
      // column of the same number.
      expect(
        out,
        contains(
          '"points":[{"label":"Sample label 1","x":42,"y":42.5},'
          '{"label":"Sample label 2","x":43,"y":43.5}]',
        ),
      );
      // A standalone object is index 0, so it keeps the 0.1 sample values.
      expect(
        out,
        contains('"origin":{"label":"Sample label","x":42,"y":42.5}'),
      );
    });

    test('nested objects and enums appear in the sample', () async {
      final out = await generate('''
enum Trend { up, down }

$badge

@GenUiData()
class Row {
  const Row({required this.label, required this.trend, this.badge});
  final String label;
  final Trend trend;
  final Badge? badge;
}

@GenUiWidget(description: 'A row.')
class RowView extends StatelessWidget {
  const RowView({super.key, required this.row});
  final Row row;
}
''');
      expect(
        out,
        contains(
          '"row":{"label":"Sample label","trend":"up",'
          '"badge":{"text":"Sample text"}}',
        ),
      );
    });

    test('entries of a list walk the enum instead of repeating it', () async {
      final out = await generate('''
enum Trend { up, down }

@GenUiData()
class Row {
  const Row({required this.label, required this.trend});
  final String label;
  final Trend trend;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''');
      expect(
        out,
        contains(
          '"rows":[{"label":"Sample label 1","trend":"up"},'
          '{"label":"Sample label 2","trend":"down"}]',
        ),
      );
    });

    test('an enum shorter than the list wraps around', () async {
      final out = await generate('''
enum Kind { only }

@GenUiData()
class Row {
  const Row({required this.kind});
  final Kind kind;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''');
      expect(out, contains('"rows":[{"kind":"only"},{"kind":"only"}]'));
    });

    test('a single object property still uses the first enum value', () async {
      final out = await generate('''
enum Trend { up, down }

@GenUiData()
class Row {
  const Row({required this.trend});
  final Trend trend;
}

@GenUiWidget(description: 'A row.')
class RowView extends StatelessWidget {
  const RowView({super.key, required this.row});
  final Row row;
}
''');
      expect(out, contains('"row":{"trend":"up"}'));
    });
  });

  group('across files', () {
    /// A second package declaring a data class, with the part directive its
    /// generated schema and decoder will live in.
    const models = {
      'models|lib/row.dart': '''
import 'package:genui_gen/genui_gen.dart';

part 'row.genui.dart';

@GenUiData(description: 'A row.')
class Row {
  const Row({required this.label});
  final String label;
}
''',
    };

    const table = '''
@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''';

    test('a widget may use a data class from another library', () async {
      final out = await generate(
        table,
        imports: "$defaultImports\nimport 'package:models/row.dart';\n",
        extraAssets: models,
      );
      expect(
        out,
        contains("'rows': A2uiSchemas.listOrReference(items: rowGenUiSchema)"),
      );
      expect(
        out,
        contains(
          "?.map((json) => rowFromGenUiJson(json, missingIn('rows'))) .toList()",
        ),
      );
      // The schema and decoder belong to the part of the other library.
      expect(out, isNot(contains('final ObjectSchema rowGenUiSchema')));
    });

    test('the data class must be visible without an import prefix', () async {
      await expectLater(
        generate(
          '''
@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<m.Row> rows;
}
''',
          imports: "$defaultImports\nimport 'package:models/row.dart' as m;\n",
          extraAssets: models,
        ),
        failsWith([
          'Data class `Row` used by `Table.rows` is not visible unprefixed',
          'name its generated schema and decoder',
        ]),
      );
    });

    test('the data class library must include its generated part', () async {
      await expectLater(
        generate(
          table,
          imports: "$defaultImports\nimport 'package:models/row.dart';\n",
          extraAssets: {
            'models|lib/row.dart': '''
import 'package:genui_gen/genui_gen.dart';

@GenUiData(description: 'A row.')
class Row {
  const Row({required this.label});
  final String label;
}
''',
          },
        ),
        failsWith([
          'Data class `Row` used by `Table.rows` is declared in '
              'package:models/row.dart',
          "has no `part 'row.genui.dart';` directive",
        ]),
      );
    });
  });

  group('reuse', () {
    test('one data class feeds two widgets in the same library', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'Shows a badge.')
class BadgeView extends StatelessWidget {
  const BadgeView({super.key, required this.badge});
  final Badge badge;
}

@GenUiWidget(description: 'Shows badges.')
class BadgeList extends StatelessWidget {
  const BadgeList({super.key, required this.badges});
  final List<Badge> badges;
}
''');
      // The schema and the decoder are declared exactly once, and both
      // catalog items refer to them.
      expect('final ObjectSchema badgeGenUiSchema'.allMatches(out).length, 1);
      expect('Badge badgeFromGenUiJson('.allMatches(out).length, 1);
      expect(out, contains('final CatalogItem badgeViewCatalogItem'));
      expect(out, contains('final CatalogItem badgeListCatalogItem'));
      expect(
        out,
        contains(
          "'badges': A2uiSchemas.listOrReference(items: badgeGenUiSchema)",
        ),
      );
      expect(
        out,
        contains(
          "'badge': S.combined(oneOf: [badgeGenUiSchema, "
          'A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()])',
        ),
      );
    });

    test('a data class may nest one declared in a third file', () async {
      final out = await generate(
        '''
@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''',
        imports: "$defaultImports\nimport 'package:models/row.dart';\n",
        extraAssets: {
          'models|lib/row.dart': '''
import 'package:genui_gen/genui_gen.dart';

import 'package:badges/badge.dart';

part 'row.genui.dart';

@GenUiData(description: 'A row.')
class Row {
  const Row({required this.label, required this.badge});
  final String label;
  final Badge badge;
}
''',
          'badges|lib/badge.dart': '''
import 'package:genui_gen/genui_gen.dart';

part 'badge.genui.dart';

@GenUiData(description: 'A badge.')
class Badge {
  const Badge({required this.text});
  final String text;
}
''',
        },
      );
      // Only the widget's own part is generated here; the two data parts
      // belong to the libraries that declare them.
      expect(
        out,
        contains("'rows': A2uiSchemas.listOrReference(items: rowGenUiSchema)"),
      );
      expect(out, isNot(contains('final ObjectSchema rowGenUiSchema')));
      expect(out, isNot(contains('badgeGenUiSchema')));
      expect(
        out,
        contains(
          "?.map((json) => rowFromGenUiJson(json, missingIn('rows'))) .toList()",
        ),
      );
      // The example still walks into the third file's fields.
      expect(out, contains('"badge":{"text":"Sample text 1"}'));
    });

    test('a widget may use a data class with a named constructor', () async {
      final out = await generate('''
@GenUiData(description: 'A row.', constructor: 'fromModel')
class Row {
  const Row.fromModel({required this.label});
  const Row.empty() : label = '';
  final String label;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''');
      expect(out, contains('=> Row.fromModel('));
      expect(
        out,
        contains(
          "?.map((json) => rowFromGenUiJson(json, missingIn('rows'))) .toList()",
        ),
      );
    });

    test('@GenUiProp(ignore:) drops an optional nullable field', () async {
      final out = await generate('''
@GenUiData()
class Row {
  const Row({required this.label, @GenUiProp(ignore: true) this.internal});
  final String label;
  final String? internal;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''');
      expect(out, isNot(contains('internal')));
      expect(out, contains("properties: {'label': S.string()}"));
      expect(
        out,
        contains(
          "Row(label: genUiAsString(json['label']) ?? "
          "genUiMissingField<String>(onMissing, 'label', ''))",
        ),
      );
    });

    test('a widget may mix List<Widget> and List<data class>', () async {
      final out = await generate('''
$badge

@GenUiWidget(description: 'A panel of badges and children.')
class Panel extends StatelessWidget {
  const Panel({super.key, required this.badges, required this.children});
  final List<Badge> badges;
  final List<Widget> children;
}
''');
      expect(
        out,
        contains(
          "'badges': A2uiSchemas.listOrReference(items: badgeGenUiSchema)",
        ),
      );
      expect(
        out,
        contains("'children': S.list(items: A2uiSchemas.componentReference())"),
      );
      // The children are read straight from `data`, never bound.
      expect(out, contains("final _children = data['children'];"));
      expect(
        out,
        contains(
          "bindings: {'badges': GenUiBinding.objectList(data['badges'])}",
        ),
      );
      expect(
        out,
        contains(
          '_children is List ? _children .whereType<String>()'
          ' .map((id) => ctx.buildChild(id)) .toList()',
        ),
      );
    });
  });
}
