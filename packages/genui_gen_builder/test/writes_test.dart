import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('value writers', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Size { small, large }

@GenUiWidget(description: 'A labelled switch with a size.')
class LabeledSwitch extends StatelessWidget {
  const LabeledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.size,
    required this.volume,
    @GenUiWrites('value') this.onChanged,
    @GenUiWrites('size') this.onSizeChanged,
    @GenUiWrites('volume') this.onVolumeChanged,
  });

  /// Text shown next to the switch.
  final String label;

  /// Whether the switch is on.
  final bool value;

  /// How big to draw it.
  final Size size;

  /// How loud the click is.
  final int volume;

  final ValueChanged<bool>? onChanged;
  final void Function(Size)? onSizeChanged;
  final ValueChanged<double>? onVolumeChanged;
}
''');
    });

    test('the callback is not a schema property', () {
      expect(out, isNot(contains("'onChanged':")));
      expect(out, isNot(contains("'onSizeChanged':")));
      expect(out, contains("required: ['label', 'value', 'size', 'volume']"));
    });

    test('the written property says so in its description', () {
      expect(
        joinLiterals(out),
        contains(
          "'value': A2uiSchemas.booleanReference(description: 'Whether the "
          'switch is on. The component writes the value the user chooses back '
          "to this property, so bind it to a data path if you need to read "
          "the result.')",
        ),
      );
    });

    test('a property nobody writes keeps its description', () {
      expect(
        out,
        contains(
          "'label': A2uiSchemas.stringReference(description: 'Text shown next "
          "to the switch.')",
        ),
      );
    });

    test('the callback writes to the path of the property it names', () {
      expect(
        out,
        contains(
          "onChanged: genUiValueWriter<bool>(ctx, data['value'], 'value')",
        ),
      );
    });

    test('an enum is written as its name', () {
      expect(
        out,
        contains(
          "onSizeChanged: genUiValueWriter<Size>(ctx, data['size'], 'size', "
          'encode: (value) => value.name)',
        ),
      );
    });

    test('a numeric callback may differ from the property it writes', () {
      expect(
        out,
        contains(
          "onVolumeChanged: genUiValueWriter<double>(ctx, data['volume'], 'volume')",
        ),
      );
    });

    test('a written property is read through the path it is written to', () {
      expect(
        out,
        contains(
          "'value': GenUiBinding.bool(genUiWriteReference(ctx, data['value'], "
          "'value'))",
        ),
      );
    });

    test('until that path holds something, the literal still wins', () {
      expect(
        out,
        contains(
          "value: (v.boolean('value') ?? genUiAsBool(data['value'])) ?? "
          "missing<bool>('value', false)",
        ),
      );
    });

    test('a property nobody writes is read straight from the data', () {
      expect(out, contains("'label': GenUiBinding.string(data['label'])"));
      expect(
        out,
        contains("label: v.string('label') ?? missing<String>('label', '')"),
      );
    });

    test('the callback stays out of the example', () {
      expect(out, isNot(contains('onChanged"')));
      expect(out, contains('"value":true'));
    });
  });

  test('the property is the wire name, not the Dart one', () async {
    final out = await generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({
    super.key,
    @GenUiProp(name: 'text') required this.content,
    @GenUiWrites('text') this.onChanged,
  });

  final String content;
  final ValueChanged<String>? onChanged;
}
''');
    expect(
      out,
      contains(
        "onChanged: genUiValueWriter<String>(ctx, data['text'], 'text')",
      ),
    );
  });

  test('a writer may be declared before the property it writes', () async {
    final out = await generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({
    super.key,
    @GenUiWrites('text') this.onChanged,
    required this.text,
  });

  final ValueChanged<String>? onChanged;
  final String text;
}
''');
    expect(
      out,
      contains(
        "onChanged: genUiValueWriter<String>(ctx, data['text'], 'text')",
      ),
    );
  });

  test('two callbacks may write the same property', () async {
    final out = await generate('''
@GenUiWidget(description: 'A slider.')
class Dial extends StatelessWidget {
  const Dial({
    super.key,
    required this.value,
    @GenUiWrites('value') this.onChanged,
    @GenUiWrites('value') this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
}
''');
    expect(
      out,
      contains(
        "onChanged: genUiValueWriter<double>(ctx, data['value'], 'value')",
      ),
    );
    expect(
      out,
      contains(
        "onChangeEnd: genUiValueWriter<double>(ctx, data['value'], 'value')",
      ),
    );
  });

  group('errors', () {
    test('a one-argument callback without the annotation', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.text, this.onChanged});
  final String text;
  final ValueChanged<String>? onChanged;
}
'''),
        failsWith([
          '`Field.onChanged` takes `void Function(String)?`',
          "@GenUiWrites('<property>')",
          '@GenUiProp(ignore: true)',
        ]),
      );
    });

    test('the annotation on something that is not a callback', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, @GenUiWrites('text') required this.text});
  final String text;
}
'''),
        failsWith([
          '@GenUiWrites on `Field.text` requires a callback',
          'its type is `String`',
        ]),
      );
    });

    test('a property the widget does not have', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.text,
    @GenUiWrites('value') this.onChanged,
  });
  final String text;
  final ValueChanged<String>? onChanged;
}
'''),
        failsWith([
          "@GenUiWrites('value') on `Field.onChanged` names a property",
          'Writable properties of `Field`: `text`',
        ]),
      );
    });

    test('a property that cannot be written back', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A list.')
class Names extends StatelessWidget {
  const Names({
    super.key,
    required this.names,
    @GenUiWrites('names') this.onChanged,
  });
  final List<String> names;
  final ValueChanged<String>? onChanged;
}
'''),
        failsWith([
          'writes to `Names.names`, which is a list',
          'Only a String, a number, a bool or an enum can be written back',
        ]),
      );
    });

    test('a callback whose type does not match the property', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.text,
    @GenUiWrites('text') this.onChanged,
  });
  final String text;
  final ValueChanged<bool>? onChanged;
}
'''),
        failsWith([
          'takes `bool`, but `Field.text` is a String',
          'has to take the same type the property carries',
        ]),
      );
    });

    test('two different enums do not match', () async {
      await expectLater(
        generate('''
enum Size { small, large }
enum Trend { up, down }

@GenUiWidget(description: 'A picker.')
class Picker extends StatelessWidget {
  const Picker({
    super.key,
    required this.size,
    @GenUiWrites('size') this.onChanged,
  });
  final Size size;
  final ValueChanged<Trend>? onChanged;
}
'''),
        failsWith(['takes `Trend`, but `Picker.size` is a enum (`Size`)']),
      );
    });

    test('a nullable argument is rejected with its own message', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.text,
    @GenUiWrites('text') this.onChanged,
  });
  final String text;
  final ValueChanged<String?>? onChanged;
}
'''),
        failsWith([
          '`Field.onChanged` is a callback whose value is `String?`',
          'no agreed meaning for writing `null` to a path',
          'Take `String` instead',
        ]),
      );
    });

    test('a callback inside a data class stays rejected', () async {
      await expectLater(
        generate('''
@GenUiData()
class Row {
  const Row({
    required this.label,
    @GenUiWrites('label') this.onChanged,
  });
  final String label;
  final ValueChanged<String>? onChanged;
}

@GenUiWidget(description: 'A table.')
class Table extends StatelessWidget {
  const Table({super.key, required this.rows});
  final List<Row> rows;
}
'''),
        failsWith(['not allowed inside a @GenUiData class']),
      );
    });

    test('a callback with two arguments is still unsupported', () async {
      await expectLater(
        generate('''
@GenUiWidget(description: 'A field.')
class Field extends StatelessWidget {
  const Field({super.key, required this.text, this.onChanged});
  final String text;
  final void Function(String, int)? onChanged;
}
'''),
        failsWith([
          'Unsupported parameter type `void Function(String, int)?`',
          'void Function(T) marked @GenUiWrites',
        ]),
      );
    });
  });
}
