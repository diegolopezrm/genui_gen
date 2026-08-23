import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('enum properties', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Variant { primary, secondary, danger }

enum Size { small, large }

@GenUiWidget(description: 'A badge.')
class Badge extends StatelessWidget {
  const Badge({
    super.key,
    /// Visual style.
    required this.variant,
    this.size = Size.large,
    this.fallbackSize,
    this.tone,
  });

  final Variant variant;
  final Size size;
  final Size? fallbackSize;
  final Variant? tone;
}
''');
    });

    test('schema lists enum names verbatim', () {
      expect(
        out,
        contains(
          "'variant': A2uiSchemas.stringReference(description: 'Visual style.', "
          "enumValues: ['primary', 'secondary', 'danger'])",
        ),
      );
      expect(
        out,
        contains(
          "'size': A2uiSchemas.stringReference(enumValues: ['small', 'large'])",
        ),
      );
      expect(out, contains("required: ['variant']"));
    });

    test('binds enums as strings', () {
      expect(out, contains("'variant': GenUiBinding.string(data['variant'])"));
    });

    test('maps names to enum values without throwing', () {
      expect(
        out,
        contains(
          "variant: Variant.values.asNameMap()[v.string('variant')] ?? "
          "missing<Variant>('variant', Variant.values.first)",
        ),
      );
      expect(
        out,
        contains(
          "size: Size.values.asNameMap()[v.string('size')] ?? Size.large",
        ),
      );
      expect(
        out,
        contains(
          "fallbackSize: Size.values.asNameMap()[v.string('fallbackSize')]",
        ),
      );
      expect(
        out,
        contains("tone: Variant.values.asNameMap()[v.string('tone')]))"),
      );
    });

    test('example uses the first enum value, also for optional enums', () {
      expect(out, contains('"variant":"primary"'));
      expect(out, contains('"size":"small"'));
      expect(out, contains('"fallbackSize":"small"'));
    });
  });

  test('enums imported from another library are referenced by name', () async {
    final out = await generate(
      '''
@GenUiWidget(description: 'Uses a shared enum.')
class Chip extends StatelessWidget {
  const Chip({super.key, required this.tone});
  final Tone tone;
}
''',
      imports: '$defaultImports\nimport "package:a/tone.dart";\n',
      extraAssets: {'a|lib/tone.dart': 'enum Tone { calm, loud }'},
    );
    expect(out, contains("enumValues: ['calm', 'loud']"));
    expect(out, contains('Tone.values.asNameMap()'));
  });
}
