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
          "'rows': A2uiSchemas.componentArrayReference("
          "description: 'One row per entry.')",
        ),
      );
    });

    test('binds the path the template repeats over', () {
      expect(
        out,
        contains("'rows': GenUiBinding.value(genUiTemplatePath(data['rows']))"),
      );
    });

    test('builds the children from what that path holds', () {
      expect(out, contains("genUiTemplateChildren(ctx,"));
      expect(out, contains("v.raw('rows')"));
    });

    test('an optional template keeps its fallback', () {
      expect(out, contains('_footers == null ? null'));
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
        contains("'children': S.list(items: A2uiSchemas.componentReference())"),
      );
      expect(plain, isNot(contains('genUiTemplateChildren')));
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
