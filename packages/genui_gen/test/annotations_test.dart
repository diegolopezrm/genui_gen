import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  test('GenUiData is const and defaults both fields to null', () {
    const GenUiData annotation = GenUiData();

    expect(annotation.description, isNull);
    expect(annotation.constructor, isNull);
  });

  test('GenUiData keeps the description and the constructor name', () {
    const GenUiData annotation = GenUiData(
      description: 'One row of a comparison table.',
      constructor: 'fromCsv',
    );

    expect(annotation.description, 'One row of a comparison table.');
    expect(annotation.constructor, 'fromCsv');
  });
}
