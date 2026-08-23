import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('string properties', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A greeting.')
class Greeting extends StatelessWidget {
  const Greeting({
    super.key,
    /// Who to greet.
    required this.name,
    this.subtitle,
    this.prefix = 'Hello',
    required this.optionalNote,
    @GenUiProp(description: 'Override wins.', name: 'label_text')
    required this.label,
  });

  final String name;

  /// Shown under the name.
  final String? subtitle;

  final String prefix;

  final String? optionalNote;

  /// Doc comment that loses to @GenUiProp.
  final String label;
}
''');
    });

    test('emits the catalog item variable', () {
      expect(
        out,
        contains('final CatalogItem greetingCatalogItem = CatalogItem('),
      );
      expect(out, contains("name: 'Greeting'"));
      expect(out, contains("description: 'A greeting.'"));
    });

    test('maps every string to stringReference', () {
      expect(
        out,
        contains(
          "'name': A2uiSchemas.stringReference(description: 'Who to greet.')",
        ),
      );
      expect(
        out,
        contains(
          "'subtitle': A2uiSchemas.stringReference(description: 'Shown under the name.')",
        ),
      );
      expect(out, contains("'prefix': A2uiSchemas.stringReference()"));
      expect(out, contains("'optionalNote': A2uiSchemas.stringReference()"));
    });

    test('required iff required, non-nullable and without default', () {
      expect(out, contains("required: ['name', 'label_text']"));
    });

    test('@GenUiProp description and name override doc comments', () {
      expect(
        out,
        contains(
          "'label_text': A2uiSchemas.stringReference(description: 'Override wins.')",
        ),
      );
      expect(out, isNot(contains('loses to')));
      expect(
        out,
        contains("'label_text': GenUiBinding.string(data['label_text'])"),
      );
      expect(
        out,
        contains(
          "label: v.string('label_text') ?? missing<String>('label_text', '')",
        ),
      );
    });

    test('binds every string through GenUiBindings', () {
      expect(out, contains('return GenUiBindings('));
      expect(out, contains('dataContext: ctx.dataContext'));
      expect(out, contains("'name': GenUiBinding.string(data['name'])"));
      expect(
        out,
        contains("'subtitle': GenUiBinding.string(data['subtitle'])"),
      );
    });

    test('required strings fall back to empty string and report', () {
      expect(
        out,
        contains("name: v.string('name') ?? missing<String>('name', '')"),
      );
      expect(out, contains('T missing<T>(String property, T fallback)'));
      expect(out, contains("genUiReportMissing(ctx, 'Greeting', property);"));
      expect(out, isNot(contains('reportError')));
    });

    test('nullable strings pass through, defaults apply when absent', () {
      expect(out, contains("subtitle: v.string('subtitle')"));
      expect(out, contains("optionalNote: v.string('optionalNote')"));
      expect(out, contains("prefix: v.string('prefix') ?? 'Hello'"));
    });

    test('example contains required strings only', () {
      expect(out, contains('"name":"Sample name"'));
      expect(out, contains('"label_text":"Sample label text"'));
      expect(out, isNot(contains('"subtitle"')));
      expect(out, isNot(contains('"prefix"')));
    });
  });

  test('multi-line doc comments are collapsed into one description', () async {
    final out = await generate('''
@GenUiWidget(description: 'Docs.')
class Docs extends StatelessWidget {
  const Docs({super.key, required this.body});

  /// First line.
  ///
  /// Second paragraph with {@macro ignored} text.
  final String body;
}
''');
    expect(
      out,
      contains("description: 'First line. Second paragraph with text.'"),
    );
  });

  test('descriptions are escaped as Dart string literals', () async {
    final out = await generate(r'''
@GenUiWidget(description: "It's \$5 or 'free'.")
class Quote extends StatelessWidget {
  const Quote({super.key, required this.text});

  /// Don't include "quotes".
  final String text;
}
''');
    expect(out, contains(r"description: 'It\'s \$5 or \'free\'.'"));
    expect(out, contains(r"""description: 'Don\'t include "quotes".'"""));
  });
}
