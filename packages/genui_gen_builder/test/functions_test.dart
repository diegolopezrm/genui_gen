import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('a generated catalog function', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Casing { upper, lower }

@GenUiFunction(description: 'Shortens a full name for display.')
String shortenName(
  /// The name to shorten.
  String name, {
  /// How to case the result.
  Casing casing = Casing.upper,
  int? maxLength,
}) => name;
''');
    });

    test('declares the name the model calls it by', () {
      expect(out, contains("name: 'shortenName'"));
      expect(
        out,
        contains('final ClientFunction shortenNameGenUiFunction'),
      );
    });

    test('derives the argument schema from the parameters', () {
      expect(
        out,
        contains(
          "'name': A2uiSchemas.stringReference("
          "description: 'The name to shorten.')",
        ),
      );
      expect(
        out,
        contains(
          "'casing': A2uiSchemas.stringReference("
          "description: 'How to case the result.', "
          "enumValues: ['upper', 'lower'])",
        ),
      );
    });

    test('requires only the parameters with no default and no null', () {
      expect(out, contains("required: ['name']"));
    });

    test('takes the return type from the Dart return type', () {
      expect(out, contains('returnType: ClientFunctionReturnType.string'));
    });

    test('coerces each argument instead of casting it', () {
      expect(out, contains("genUiAsString(json['name'])"));
      expect(
        out,
        contains("Casing.values.asNameMap()[genUiAsString(json['casing'])]"),
      );
      expect(out, contains("genUiAsNum(json['maxLength'])?.toInt()"));
    });

    test('applies the Dart default when the model omits the argument', () {
      expect(out, contains('?? Casing.upper'));
    });

    test('passes named parameters by name and positional ones by position', () {
      expect(out, contains('casing:'));
      expect(out, isNot(contains('name:genUiAsString')));
    });
  });

  group('how the answer is delivered', () {
    test('a Future is emitted through the async constructor', () async {
      final out = await generate('''
@GenUiFunction(description: 'Looks a price up.')
Future<int> priceOf(String sku) async => 0;
''');
      expect(out, contains('GenUiClientFunction.async'));
      expect(out, contains('returnType: ClientFunctionReturnType.number'));
    });

    test('a Stream is emitted through the streaming constructor', () async {
      final out = await generate('''
@GenUiFunction(description: 'Ticks once a second.')
Stream<String> clock() async* {}
''');
      expect(out, contains('GenUiClientFunction.streaming'));
    });

    test('a function with no arguments takes an empty schema', () async {
      final out = await generate('''
@GenUiFunction(description: 'The current greeting.')
String greeting() => '';
''');
      expect(out, contains('argumentSchema: S.object(properties: {})'));
      expect(out, contains('return greeting();'));
    });

    test('void becomes the empty return type', () async {
      final out = await generate('''
@GenUiFunction(description: 'Does something.')
void ping() {}
''');
      expect(out, contains('returnType: ClientFunctionReturnType.empty'));
    });
  });

  group('what a catalog function may not be', () {
    test('a private function, because nothing could name the variable', () {
      expect(
        generate('''
@GenUiFunction(description: 'Hidden.')
String _hidden() => '';
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('is private'),
          ),
        ),
      );
    });

    test('named after one of the basic catalog functions', () {
      expect(
        generate('''
@GenUiFunction(description: 'Mine.')
bool required(String value) => true;
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains("basic catalog"),
          ),
        ),
      );
    });

    test('taking a widget, which a function has nothing to build', () {
      expect(
        generate('''
@GenUiFunction(description: 'Mine.')
String label(Widget child) => '';
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('catalog function cannot take'),
          ),
        ),
      );
    });

    test('returning something the model cannot receive', () {
      expect(
        generate('''
class Opaque {}

@GenUiFunction(description: 'Mine.')
Opaque build() => Opaque();
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('cannot describe to the model'),
          ),
        ),
      );
    });

    test('described with nothing, which is useless to the model', () {
      expect(
        generate('''
@GenUiFunction(description: '  ')
String thing() => '';
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('empty description'),
          ),
        ),
      );
    });
  });
}
