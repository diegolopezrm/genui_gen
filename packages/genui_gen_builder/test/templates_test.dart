import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('a template list of children', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A table.')
class DataTable extends StatelessWidget {
  const DataTable({
    super.key,
    required this.title,
    /// One row per entry.
    @GenUiProp(template: true) required this.rows,
    @GenUiProp(template: true) this.footers,
  });

  final String title;
  final List<Widget> rows;
  final List<Widget>? footers;
}
''');
    });

    test('accepts both a list of ids and a template', () {
      expect(
        out,
        contains(
          "'rows': S.fromMap({...CommonSchemas.childList.value, "
          "'description': 'One row per entry.'})",
        ),
      );
    });

    test('builds one child per node the renderer expanded the template to', () {
      expect(
        out,
        contains(
          "rows: props.value('rows') is List "
          "? [for (final child in props.children('rows')) buildChild(child)] "
          ": missing<List<Widget>>('rows', const <Widget>[])",
        ),
      );
    });

    test('an optional template keeps its fallback', () {
      expect(
        out,
        contains(
          "footers: props.value('footers') is List "
          "? [for (final child in props.children('footers')) "
          'buildChild(child)] : null',
        ),
      );
    });

    test('a plain list of children is left as it was', () async {
      final plain = await generate('''
@GenUiWidget(description: 'A row.')
class Strip extends StatelessWidget {
  const Strip({super.key, required this.children});

  final List<Widget> children;
}
''');

      expect(
        plain,
        contains("'children': S.list(items: CommonSchemas.componentId)"),
      );
      expect(plain, isNot(contains('childList')));
    });
  });

  test('a template on anything else is rejected, and says why', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'A card.')
class Card extends StatelessWidget {
  const Card({super.key, @GenUiProp(template: true) required this.title});

  final String title;
}
'''),
      failsWith(['template: true', 'List<Widget>', 'Card.title']),
    );
  });
}
