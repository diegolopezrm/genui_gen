import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('a component the agent may attach rules to', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A labelled text input.')
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    @GenUiChecked() this.error,
  });

  final String label;
  final String value;
  final String? error;
}
''');
    });

    test('publishes a checks property so the model may send rules', () {
      expect(out, contains("'checks': A2uiSchemas.checkable()"));
    });

    test('does not require the rules', () {
      expect(out, contains("required: ['label', 'value']"));
    });

    test('evaluates them outside the bindings', () {
      expect(
        out,
        contains(
          "return GenUiChecks(dataContext: ctx.dataContext, "
          "checks: data['checks'], builder: (context, checked) =>",
        ),
      );
    });

    test('hands a String? the message of the failing rule', () {
      expect(out, contains('error: checked.message'));
    });

    test('leaves the parameter out of the example', () {
      expect(out, isNot(contains('"error"')));
    });
  });

  group('what the parameter may be', () {
    test('a bool takes whether every rule passes', () async {
      final out = await generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.value, @GenUiChecked() this.ok = true});
  final String value;
  final bool ok;
}
''');
      expect(out, contains('ok: checked.isValid'));
    });

    test('a GenUiCheckResult takes both', () async {
      final out = await generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.value, @GenUiChecked() this.state});
  final String value;
  final GenUiCheckResult? state;
}
''');
      expect(out, contains('state: checked'));
    });

    test('a non-nullable String is a build error, since passing has no message',
        () {
      expect(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.value, @GenUiChecked() this.error = ''});
  final String value;
  final String error;
}
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('needs a parameter that can hold the answer'),
          ),
        ),
      );
    });

    test('anything else is a build error naming the parameter', () {
      expect(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.value, @GenUiChecked() this.count});
  final String value;
  final int? count;
}
'''),
        throwsA(
          isA<GenerationFailure>().having(
            (e) => e.message,
            'message',
            contains('needs a parameter that can hold the answer'),
          ),
        ),
      );
    });
  });

  test('a widget with nothing but checks still publishes them', () async {
    final out = await generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, @GenUiChecked() this.error});
  final String? error;
}
''');
    expect(out, contains("'checks': A2uiSchemas.checkable()"));
    expect(out, contains('error: checked.message'));
  });
}
