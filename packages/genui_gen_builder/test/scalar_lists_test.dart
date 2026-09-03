import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('lists of scalars', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Size { small, large }

@GenUiWidget(description: 'A chart.')
class Chart extends StatelessWidget {
  const Chart({
    super.key,
    required this.counts,
    required this.ratios,
    required this.values,
    required this.sizes,
    this.spare = const <int>[],
  });

  /// Counts per bucket.
  final List<int> counts;
  final List<double> ratios;
  final List<num> values;
  final List<Size> sizes;
  final List<int> spare;
}
''');
    });

    test('numeric lists become a list-or-reference of numbers', () {
      expect(
        out,
        contains(
          "'counts': A2uiSchemas.listOrReference("
          "description: 'Counts per bucket.', items: S.number())",
        ),
      );
      expect(
        out,
        contains("'ratios': A2uiSchemas.listOrReference(items: S.number())"),
      );
      expect(
        out,
        contains("'values': A2uiSchemas.listOrReference(items: S.number())"),
      );
    });

    test('an enum list carries the enum values on its items', () {
      expect(
        out,
        contains(
          "'sizes': A2uiSchemas.listOrReference("
          "items: S.string(enumValues: ['small', 'large']))",
        ),
      );
    });

    test('numeric lists bind through numberList', () {
      expect(
        out,
        contains("'counts': GenUiBinding.numberList(data['counts'])"),
      );
      expect(
        out,
        contains("'ratios': GenUiBinding.numberList(data['ratios'])"),
      );
      expect(
        out,
        contains("'values': GenUiBinding.numberList(data['values'])"),
      );
    });

    test('an enum list binds through stringList', () {
      expect(out, contains("'sizes': GenUiBinding.stringList(data['sizes'])"));
    });

    test('elements convert to the declared element type', () {
      expect(
        out,
        contains(
          "counts: v.numberList('counts')?.map((n) => n.toInt()).toList()",
        ),
      );
      expect(
        out,
        contains(
          "ratios: v.numberList('ratios')?.map((n) => n.toDouble()).toList()",
        ),
      );
      expect(out, contains("values: v.numberList('values')"));
    });

    test('an enum list maps names and drops the ones the enum lacks', () {
      expect(
        out,
        allOf([
          contains(".stringList('sizes')"),
          contains('.map((name) => Size.values.asNameMap()[name])'),
          contains('.nonNulls'),
        ]),
      );
    });

    test('a required list falls back to an empty list of its type', () {
      expect(out, contains("missing<List<int>>('counts', const <int>[])"));
      expect(
        out,
        contains("missing<List<double>>('ratios', const <double>[])"),
      );
      expect(out, contains("missing<List<Size>>('sizes', const <Size>[])"));
    });

    test('an optional list with a default is not required', () {
      expect(
        out,
        contains("required: ['counts', 'ratios', 'values', 'sizes']"),
      );
      expect(out, contains("spare: v.numberList('spare')"));
    });

    test('examples carry a list of the right shape', () {
      expect(out, contains('"counts":[1, 2]'));
      expect(out, contains('"ratios":[1.5, 2.5]'));
      expect(out, contains('"sizes":["small","large"]'));
    });
  });

  group('lists of scalars inside a data class', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
enum Size { small, large }

@GenUiData()
class Series {
  const Series({
    required this.counts,
    required this.ratios,
    required this.sizes,
  });
  final List<int> counts;
  final List<double> ratios;
  final List<Size> sizes;
}

@GenUiWidget(description: 'A chart.')
class Chart extends StatelessWidget {
  const Chart({super.key, required this.series});
  final Series series;
}
''');
    });

    test('an int list is validated as integers, a double list as numbers', () {
      expect(out, contains("'counts': S.list(items: S.integer())"));
      expect(out, contains("'ratios': S.list(items: S.number())"));
    });

    test('an enum list keeps its values inside the object schema', () {
      expect(
        out,
        contains(
          "'sizes': S.list(items: S.string(enumValues: ['small', 'large']))",
        ),
      );
    });

    test('the decoder coerces rather than casting', () {
      expect(
        out,
        allOf([
          contains("genUiAsNumList(json['counts'])"),
          contains('.map((n) => n.toInt())'),
          contains("genUiAsStringList(json['sizes'])"),
          contains('.map((name) => Size.values.asNameMap()[name])'),
          contains('.nonNulls'),
        ]),
      );
    });
  });
}
