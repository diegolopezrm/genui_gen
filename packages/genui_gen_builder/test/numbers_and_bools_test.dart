import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('numbers and bools', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A stat tile.')
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.count,
    required this.ratio,
    required this.value,
    required this.highlighted,
    this.maxItems = 10,
    this.scale = 1.5,
    this.threshold,
    this.enabled = true,
    this.dense,
  });

  final int count;
  final double ratio;
  final num value;
  final bool highlighted;
  final int maxItems;
  final double scale;
  final num? threshold;
  final bool enabled;
  final bool? dense;
}
''');
    });

    test('maps numbers to DynamicNumber and bools to DynamicBoolean', () {
      expect(out, contains("'count': CommonSchemas.dynamicNumber"));
      expect(out, contains("'ratio': CommonSchemas.dynamicNumber"));
      expect(out, contains("'value': CommonSchemas.dynamicNumber"));
      expect(out, contains("'threshold': CommonSchemas.dynamicNumber"));
      expect(out, contains("'highlighted': CommonSchemas.dynamicBoolean"));
      expect(out, contains("'dense': CommonSchemas.dynamicBoolean"));
    });

    test('schema required list', () {
      expect(
        out,
        contains("required: ['count', 'ratio', 'value', 'highlighted']"),
      );
    });

    test('reads numbers and bools through their coercions', () {
      expect(out, contains("genUiAsNum(props.value('count'))"));
      expect(out, contains("genUiAsNum(props.value('scale'))"));
      expect(out, contains("genUiAsBool(props.value('highlighted'))"));
    });

    test('required numbers convert with fallback 0', () {
      expect(
        out,
        contains(
          "count: (genUiAsNum(props.value('count')) ?? "
          "missing<num>('count', 0)) .toInt()",
        ),
      );
      expect(
        out,
        contains(
          "ratio: (genUiAsNum(props.value('ratio')) ?? "
          "missing<num>('ratio', 0)) .toDouble()",
        ),
      );
      expect(
        out,
        contains(
          "value: genUiAsNum(props.value('value')) ?? missing<num>('value', 0)",
        ),
      );
      expect(
        out,
        contains(
          "highlighted: genUiAsBool(props.value('highlighted')) ?? missing<bool>('highlighted', false)",
        ),
      );
    });

    test('defaults apply when the value is absent', () {
      expect(
        out,
        contains(
          "maxItems: genUiAsNum(props.value('maxItems'))?.toInt() ?? 10",
        ),
      );
      expect(
        out,
        contains("scale: genUiAsNum(props.value('scale'))?.toDouble() ?? 1.5"),
      );
      expect(
        out,
        contains("enabled: genUiAsBool(props.value('enabled')) ?? true"),
      );
    });

    test('non-literal defaults are parenthesised', () async {
      final out = await generate('''
const kFlag = true;
const kDefault = 7;

@GenUiWidget(description: 'Defaults.')
class Defaults extends StatelessWidget {
  const Defaults({
    super.key,
    this.n = kFlag ? 1 : 2,
    this.m = kDefault,
    this.sum = 1 + 2,
    this.child = kFlag ? const SizedBox() : null,
  });
  final int n;
  final int m;
  final int sum;
  final Widget? child;
}
''');
      expect(
        out,
        contains("n: genUiAsNum(props.value('n'))?.toInt() ?? (kFlag ? 1 : 2)"),
      );
      expect(
        out,
        contains("m: genUiAsNum(props.value('m'))?.toInt() ?? kDefault"),
      );
      expect(
        out,
        contains("sum: genUiAsNum(props.value('sum'))?.toInt() ?? (1 + 2)"),
      );
      expect(
        out,
        contains(
          "child: switch (props.child('child')) {final child? => "
          'buildChild(child), _ => (kFlag ? const SizedBox() : null)}',
        ),
      );
    });

    test('nullable values pass through', () {
      expect(out, contains("threshold: genUiAsNum(props.value('threshold'))"));
      expect(out, contains("dense: genUiAsBool(props.value('dense'))"));
    });

    test(
      'the example samples required values and leaves optional ones out',
      () {
        // A name the generator recognises gets a number that reads like one of
        // its kind; anything else falls back to 42 / 42.5.
        expect(out, contains('"count":3'));
        expect(out, contains('"ratio":0.65'));
        expect(out, contains('"value":42'));
        expect(out, contains('"highlighted":true'));
        expect(out, isNot(contains('"maxItems"')));
        expect(out, isNot(contains('"dense"')));
      },
    );
  });
}
