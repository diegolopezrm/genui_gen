import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('types inside a data class', () {
    test('a Widget field is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.leading});
  final Widget leading;
}
'''),
        failsWith([
          '`Row.leading` has type `Widget`, which is not allowed inside a '
              '@GenUiData class',
          'not a component reference or a callback',
          'lib/widget.dart',
        ]),
      );
    });

    test('a List<Widget> field is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.children});
  final List<Widget> children;
}
'''),
        failsWith([
          '`Row.children` has type `List<Widget>`, which is not allowed '
              'inside a @GenUiData class',
        ]),
      );
    });

    test('a callback field is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.onTap});
  final VoidCallback onTap;
}
'''),
        failsWith([
          '`Row.onTap` has type `void Function()`, which is not allowed '
              'inside a @GenUiData class',
        ]),
      );
    });

    test('an unsupported type lists the data types', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.value});
  final Object value;
}
'''),
        failsWith([
          'Unsupported parameter type `Object` for `Row.value`',
          'Supported types: String, int, double, num, bool, enums, '
              'List<String>, a @GenUiData class and a List of one',
        ]),
      );
      // The data summary never offers Widget or a callback.
      final failure = await generate('''
@GenUiData()
class Row {
  const Row({required this.value});
  final Object value;
}
''').then<Object?>((_) => null, onError: (Object e) => e);
      expect('$failure', isNot(contains('List<Widget>')));
    });
  });

  group('cycles', () {
    test('a data class reaching itself is reported', () async {
      await expectLater(
        generate('''
@GenUiData()
class Node {
  const Node({required this.label, this.child});
  final String label;
  final Node? child;
}
'''),
        failsWith([
          'Data class cycle: Node -> Node',
          'inlined schema cannot describe itself',
        ]),
      );
    });

    test('an indirect cycle reports the whole path', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({this.cell});
  final Cell? cell;
}

@GenUiData()
class Cell {
  const Cell({this.row});
  final Row? row;
}
'''),
        failsWith(['Data class cycle: Row -> Cell -> Row']),
      );
    });
  });

  group('constructors', () {
    test('a missing unnamed constructor is reported', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row.named({required this.label});
  final String label;
}
'''),
        failsWith([
          '@GenUiData on `Row` expects an unnamed constructor, but none was '
              'found',
          "Pass `constructor: '<name>'`",
        ]),
      );
    });

    test('an unknown named constructor is reported', () async {
      await expectLater(
        generate('''
@GenUiData(constructor: 'other')
class Row {
  const Row({required this.label});
  final String label;
}
'''),
        failsWith([
          '@GenUiData on `Row` expects a constructor named `other`, but none '
              'was found',
        ]),
      );
    });

    test('an abstract data class is reported', () async {
      await expectLater(
        generate('''
@GenUiData()
abstract class Row {
  const Row();
}
'''),
        failsWith([
          '@GenUiData cannot be applied to abstract class `Row`',
          'the generated decoder must instantiate it',
        ]),
      );
    });

    test('an ignored required field is reported', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({@GenUiProp(ignore: true) required this.label});
  final String label;
}
'''),
        failsWith([
          '`Row.label` is marked @GenUiProp(ignore: true) but it is a '
              'required parameter, so the generated decoder could not '
              'construct the value without it',
        ]),
      );
    });

    test('duplicate schema names are reported', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.label, @GenUiProp(name: 'label') this.other});
  final String label;
  final String? other;
}
'''),
        failsWith(['Property name `label` is used by both']),
      );
    });
  });

  group('annotation placement', () {
    test('@GenUiData on a non-class is reported', () async {
      await expectLater(
        generate('''
@GenUiData()
void helper() {}
'''),
        failsWith([
          '@GenUiData can only be applied to classes, but `helper` is a',
        ]),
      );
    });

    test('a class cannot be both a widget and a data class', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'Both.')
@GenUiData()
class Both extends StatelessWidget {
  const Both({super.key});
}
'''),
        failsWith([
          '`Both` is annotated with both @GenUiWidget and @GenUiData',
        ]),
      );
    });

    test('two data classes may not share a generated name', () async {
      await expectLater(
        generate('''
@GenUiData()
class HTTPRow {
  const HTTPRow({required this.label});
  final String label;
}

@GenUiData()
class HttpRow {
  const HttpRow({required this.label});
  final String label;
}
'''),
        failsWith([
          'Classes `HTTPRow` and `HttpRow` would both generate '
              '`httpRowGenUiSchema`',
        ]),
      );
    });
  });

  group('unannotated classes', () {
    test('a custom class is reported with the annotation hint', () async {
      await expectLater(
        generate('''
class Point {
  const Point(this.x);
  final double x;
}

@GenUiWidget(description: 'A chart.')
class Chart extends StatelessWidget {
  const Chart({super.key, required this.origin});
  final Point origin;
}
'''),
        failsWith([
          'Unsupported parameter type `Point` for `Chart.origin`',
          'add @GenUiData to Point',
        ]),
      );
    });

    test('a list of a custom class is reported with the hint', () async {
      await expectLater(
        generate('''
class Point {
  const Point(this.x);
  final double x;
}

@GenUiWidget(description: 'A chart.')
class Chart extends StatelessWidget {
  const Chart({super.key, required this.points});
  final List<Point> points;
}
'''),
        failsWith([
          'Unsupported parameter type `List<Point>` for `Chart.points`',
          'add @GenUiData to Point',
        ]),
      );
    });

    test('SDK types are never suggested for @GenUiData', () async {
      final failure = await generate('''
@GenUiWidget(description: 'A clock.')
class Clock extends StatelessWidget {
  const Clock({super.key, required this.every});
  final Duration every;
}
''').then<Object?>((_) => null, onError: (Object e) => e);
      expect('$failure', contains('Unsupported parameter type `Duration`'));
      expect('$failure', isNot(contains('add @GenUiData')));
    });
  });

  group('reserved and generic shapes', () {
    test('a generic data class is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Box<T> {
  const Box({required this.label});
  final String label;
}

@GenUiWidget(description: 'A box view.')
class BoxView extends StatelessWidget {
  const BoxView({super.key, required this.box});
  final Box<String> box;
}
'''),
        failsWith([
          '@GenUiData cannot be applied to generic class `Box<T>`',
          'cannot express a type parameter',
        ]),
      );
    });

    test('a field whose wire key is `path` is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.path});
  final String path;
}
'''),
        failsWith([
          'Field `Row.path` would use the wire key `path`',
          'resolved as a data binding',
          "@GenUiProp(name: '<other>')",
        ]),
      );
    });

    test('a field renamed to `call` is rejected too', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({@GenUiProp(name: 'call') required this.label});
  final String label;
}
'''),
        failsWith(['Field `Row.label` would use the wire key `call`']),
      );
    });

    test('a data class keeps a field called `key`', () async {
      final out = await generate('''
@GenUiData()
class SortKey {
  const SortKey({required this.name});
  final String name;
}

@GenUiData()
class Row {
  const Row({required this.key, required this.label});
  final SortKey key;
  final String label;
}
''');
      // A widget skips `key` because of `super.key`; a data class has no such
      // parameter, so dropping it would break the generated decoder.
      expect(out, contains("'key': sortKeyGenUiSchema"));
      expect(out, contains("key: switch (genUiAsObject(json['key']))"));
      expect(out, contains("required: ['key', 'label']"));
    });

    test('a list with nullable elements is rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({required this.label});
  final String label;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row?> rows;
}
'''),
        failsWith([
          '`Table.rows` has type `List<Row?>`, whose elements are nullable',
          'Use `List<Row>`',
        ]),
      );
    });

    test('a list of an unsupported type keeps the general message', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A view.')
class View extends StatelessWidget {
  const View({super.key, required this.counts});
  final List<int?> counts;
}
'''),
        failsWith([
          'Unsupported parameter type `List<int?>` for `View.counts`',
          'Supported types:',
        ]),
      );
    });

    test('an unresolved type names the likely cause', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A view.')
class View extends StatelessWidget {
  const View({super.key, required this.thing});
  final NoSuchType thing;
}
'''),
        failsWith([
          'The type of `View.thing` could not be resolved',
          'missing import',
        ]),
      );
    });
  });

  group('generated names across libraries', () {
    const rowA = '''
import 'package:genui_gen/genui_gen.dart';

part 'row.genui.dart';

@GenUiData()
class HTTPRow {
  const HTTPRow({required this.label});
  final String label;
}
''';
    const rowB = '''
import 'package:genui_gen/genui_gen.dart';

part 'row.genui.dart';

@GenUiData()
class HttpRow {
  const HttpRow({required this.label});
  final String label;
}
''';
    const row = '''
import 'package:genui_gen/genui_gen.dart';

part 'row.genui.dart';

@GenUiData()
class Row {
  const Row({required this.label});
  final String label;
}
''';
    const table = '''
@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
''';

    test('a use-site collision is reported with both files', () async {
      await expectLater(
        generate(
          '''
@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.a, required this.b});
  final HTTPRow a;
  final HttpRow b;
}
''',
          imports:
              "$defaultImports\nimport 'package:a_models/row.dart';\n"
              "import 'package:b_models/row.dart';\n",
          extraAssets: {
            'a_models|lib/row.dart': rowA,
            'b_models|lib/row.dart': rowB,
          },
        ),
        failsWith([
          'Data classes `HTTPRow` (package:a_models/row.dart) and `HttpRow` '
              '(package:b_models/row.dart)',
          'would both generate `httpRowGenUiSchema`',
        ]),
      );
    });

    test('a show combinator that hides the generated names fails', () async {
      await expectLater(
        generate(
          table,
          imports:
              "$defaultImports\nimport 'package:models/row.dart' show Row;\n",
          extraAssets: {'models|lib/row.dart': row},
        ),
        failsWith([
          'Data class `Row` used by `Table.rows` is imported from '
              'package:models/row.dart with a combinator',
          '`show Row` leaves out rowGenUiSchema and rowFromGenUiJson',
        ]),
      );
    });

    test('a hide combinator on a generated name fails', () async {
      await expectLater(
        generate(
          table,
          imports:
              "$defaultImports\nimport 'package:models/row.dart' "
              'hide rowFromGenUiJson;\n',
          extraAssets: {'models|lib/row.dart': row},
        ),
        failsWith(['`hide rowFromGenUiJson` removes rowFromGenUiJson']),
      );
    });

    test('a show combinator listing the generated names is fine', () async {
      final out = await generate(
        table,
        imports:
            "$defaultImports\nimport 'package:models/row.dart' "
            'show Row, rowGenUiSchema, rowFromGenUiJson;\n',
        extraAssets: {'models|lib/row.dart': row},
      );
      expect(out, contains('rowGenUiSchema'));
    });
  });
}
