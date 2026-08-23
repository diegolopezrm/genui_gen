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

    test('maps numbers to numberReference and bools to booleanReference', () {
      expect(out, contains("'count': A2uiSchemas.numberReference()"));
      expect(out, contains("'ratio': A2uiSchemas.numberReference()"));
      expect(out, contains("'value': A2uiSchemas.numberReference()"));
      expect(out, contains("'threshold': A2uiSchemas.numberReference()"));
      expect(out, contains("'highlighted': A2uiSchemas.booleanReference()"));
      expect(out, contains("'dense': A2uiSchemas.booleanReference()"));
    });

    test('schema required list', () {
      expect(
        out,
        contains("required: ['count', 'ratio', 'value', 'highlighted']"),
      );
    });

    test('uses number and bool bindings', () {
      expect(out, contains("'count': GenUiBinding.number(data['count'])"));
      expect(out, contains("'scale': GenUiBinding.number(data['scale'])"));
      expect(
        out,
        contains("'highlighted': GenUiBinding.bool(data['highlighted'])"),
      );
    });

    test('required numbers convert with fallback 0', () {
      expect(
        out,
        contains(
          "count: (v.number('count') ?? missing<num>('count', 0)).toInt()",
        ),
      );
      expect(
        out,
        contains(
          "ratio: (v.number('ratio') ?? missing<num>('ratio', 0)).toDouble()",
        ),
      );
      expect(
        out,
        contains("value: v.number('value') ?? missing<num>('value', 0)"),
      );
      expect(
        out,
        contains(
          "highlighted: v.boolean('highlighted') ?? missing<bool>('highlighted', false)",
        ),
      );
    });

    test('defaults apply when the value is absent', () {
      expect(out, contains("maxItems: v.number('maxItems')?.toInt() ?? 10"));
      expect(out, contains("scale: v.number('scale')?.toDouble() ?? 1.5"));
      expect(out, contains("enabled: v.boolean('enabled') ?? true"));
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
      expect(out, contains("n: v.number('n')?.toInt() ?? (kFlag ? 1 : 2)"));
      expect(out, contains("m: v.number('m')?.toInt() ?? kDefault"));
      expect(out, contains("sum: v.number('sum')?.toInt() ?? (1 + 2)"));
      expect(
        out,
        contains(
          'child: _child is String ? ctx.buildChild(_child) : (kFlag ? const SizedBox() : null)',
        ),
      );
    });

    test('nullable values pass through', () {
      expect(out, contains("threshold: v.number('threshold')"));
      expect(out, contains("dense: v.boolean('dense')"));
    });

    test('example uses 42 / 42.5 / true for required values only', () {
      expect(out, contains('"count":42'));
      expect(out, contains('"ratio":42.5'));
      expect(out, contains('"value":42'));
      expect(out, contains('"highlighted":true'));
      expect(out, isNot(contains('"maxItems"')));
      expect(out, isNot(contains('"dense"')));
    });
  });
}
