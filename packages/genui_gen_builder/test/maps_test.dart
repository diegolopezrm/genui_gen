import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('a map property', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Tone { warm, cold }

@GenUiWidget(description: 'A thing.')
class Thing extends StatelessWidget {
  const Thing({
    super.key,
    required this.labels,
    required this.counts,
    required this.sizes,
    required this.flags,
    required this.tones,
    this.raw,
  });

  /// One label per key.
  final Map<String, String> labels;
  final Map<String, int> counts;
  final Map<String, double> sizes;
  final Map<String, bool> flags;
  final Map<String, Tone> tones;
  final Map<String, Object?>? raw;
}
''');
    });

    test('says what the values are and nothing about the keys', () {
      expect(
        out,
        contains(
          "'labels': S.combined(description: 'One label per key.', "
          'oneOf: [S.object(additionalProperties: S.string())',
        ),
      );
      expect(
        out,
        contains(
          "'counts': S.combined(oneOf: [S.object("
          'additionalProperties: S.integer())',
        ),
      );
      expect(
        out,
        contains(
          "'flags': S.combined(oneOf: [S.object("
          'additionalProperties: S.boolean())',
        ),
      );
    });

    test('an enum map publishes the values the enum declares', () {
      expect(
        out,
        contains(
          "additionalProperties: S.string(enumValues: ['warm', 'cold'])",
        ),
      );
    });

    test('an Object? map says nothing at all, which is the point', () {
      expect(
        out,
        contains(
          "'raw': S.combined(oneOf: [S.object("
          'additionalProperties: true)',
        ),
      );
    });

    test('accepts a binding or a call for the map as a whole', () {
      expect(
        out,
        contains('A2uiSchemas.dataBindingSchema(), A2uiSchemas.functionCall()'),
      );
    });

    test('resolves through the object binding', () {
      expect(out, contains("'labels': GenUiBinding.object(data['labels'])"));
    });

    test('coerces the values rather than casting them', () {
      expect(out, contains("genUiAsStringMap(v.object('labels'))"));
      expect(out, contains("genUiAsNumMap(v.object('counts'))"));
      expect(out, contains('value.toInt()'));
      expect(out, contains('value.toDouble()'));
      expect(out, contains("genUiAsBoolMap(v.object('flags'))"));
    });

    test(
      'a required map that never arrives is reported, not silently empty',
      () {
        expect(out, contains("missing<Map<String, String>>('labels'"));
        // The enum branch has to keep propagating null for that to work.
        expect(out, contains("missing<Map<String, Tone>>('tones'"));
        expect(out, contains('_ => null'));
      },
    );

    test('an optional one is just null', () {
      expect(out, contains("raw: genUiAsObject(v.object('raw'))"));
    });
  });

  group('what a map may not be', () {
    test('a non-string key, since JSON object keys are strings', () async {
      expect(
        generate('''
@GenUiWidget(description: 'A thing.')
class Thing extends StatelessWidget {
  const Thing({super.key, required this.byIndex});
  final Map<int, String> byIndex;
}
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('Unsupported parameter type `Map<int, String>`'),
          ),
        ),
      );
    });

    test('a nullable value, which the schema cannot say', () async {
      expect(
        generate('''
@GenUiWidget(description: 'A thing.')
class Thing extends StatelessWidget {
  const Thing({super.key, required this.maybe});
  final Map<String, String?> maybe;
}
'''),
        throwsA(isA<GenerationFailure>()),
      );
    });
  });

  test('a map is allowed inside a @GenUiData class', () async {
    final out = await generate('''
@GenUiData(description: 'A row.')
class Row {
  const Row({required this.extras});
  /// Anything else worth attaching.
  final Map<String, String> extras;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.row});
  final Row row;
}
''');
    expect(
      out,
      contains(
        "'extras': S.object(description: 'Anything else worth attaching.', "
        'additionalProperties: S.string())',
      ),
    );
    expect(out, contains("genUiAsStringMap(json['extras'])"));
  });

  test('a catalog function may take one too', () async {
    final out = await generate('''
@GenUiFunction(description: 'Looks a label up.')
String lookUp(Map<String, String> labels, String key) => '';
''');
    expect(
      out,
      contains(
        "'labels': S.combined(oneOf: [S.object("
        'additionalProperties: S.string())',
      ),
    );
    expect(out, contains("genUiAsStringMap(json['labels'])"));
  });
  group('a record', () {
    test('is rejected with the reason, and the way forward', () {
      expect(
        generate(recordNamed),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('A record is not supported'),
              contains('nowhere to put a doc comment'),
              contains('@GenUiData'),
            ),
          ),
        ),
      );
    });

    test('a positional one says the same thing', () {
      expect(generate(recordPositional), throwsA(isA<GenerationFailure>()));
    });
  });
}

const recordNamed = '''
@GenUiWidget(description: 'A thing.')
class Thing extends StatelessWidget {
  const Thing({super.key, required this.who});
  final ({String name, int age}) who;
}
''';

const recordPositional = '''
@GenUiWidget(description: 'A thing.')
class Thing extends StatelessWidget {
  const Thing({super.key, required this.pair});
  final (String, int) pair;
}
''';
