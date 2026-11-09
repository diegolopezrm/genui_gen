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

    test('maps every string to DynamicString', () {
      expect(
        out,
        contains(
          "'name': S.fromMap({...CommonSchemas.dynamicString.value, "
          "'description': 'Who to greet.'})",
        ),
      );
      expect(
        out,
        contains(
          "'subtitle': S.fromMap({...CommonSchemas.dynamicString.value, "
          "'description': 'Shown under the name.'})",
        ),
      );
      expect(out, contains("'prefix': CommonSchemas.dynamicString,"));
      expect(out, contains("'optionalNote': CommonSchemas.dynamicString,"));
    });

    test('required iff required, non-nullable and without default', () {
      expect(out, contains("required: ['name', 'label_text']"));
    });

    test('@GenUiProp description and name override doc comments', () {
      expect(
        out,
        contains(
          "'label_text': S.fromMap({...CommonSchemas.dynamicString.value, "
          "'description': 'Override wins.'})",
        ),
      );
      expect(out, isNot(contains('loses to')));
      expect(
        out,
        contains(
          "label: genUiAsString(props.value('label_text')) ?? "
          "missing<String>('label_text', '')",
        ),
      );
    });

    test('reads every string from the resolved properties', () {
      expect(out, contains('builder: (context, node, props, buildChild) {'));
      expect(out, contains('return Greeting('));
      expect(out, contains("genUiAsString(props.value('name'))"));
      expect(out, contains("genUiAsString(props.value('subtitle'))"));
    });

    test('required strings fall back to empty string and report', () {
      expect(
        out,
        contains(
          "name: genUiAsString(props.value('name')) ?? "
          "missing<String>('name', '')",
        ),
      );
      expect(out, contains('T missing<T>(String property, T fallback)'));
      expect(out, contains("genUiReportMissing(node, 'Greeting', property);"));
      expect(out, isNot(contains('reportError')));
    });

    test('nullable strings pass through, defaults apply when absent', () {
      expect(out, contains("subtitle: genUiAsString(props.value('subtitle'))"));
      expect(
        out,
        contains("optionalNote: genUiAsString(props.value('optionalNote'))"),
      );
      expect(
        out,
        contains("prefix: genUiAsString(props.value('prefix')) ?? 'Hello'"),
      );
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
      contains("'description': 'First line. Second paragraph with text.'"),
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
    expect(out, contains(r"""'description': 'Don\'t include "quotes".'"""));
  });
}
