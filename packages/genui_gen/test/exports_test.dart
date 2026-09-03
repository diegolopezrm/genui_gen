import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  group('re-exported schema symbols', () {
    // The generated part is `part of` the annotated library and builds its
    // schema with these three names, so an annotated file that imports only
    // this package has to see them.
    test('S builds a schema', () {
      final schema = S.object(
        description: 'A product.',
        properties: {'title': S.string()},
        required: ['title'],
      );
      expect(schema.value['description'], 'A product.');
      expect((schema.value['required']! as List).single, 'title');
    });

    test('Schema is the type S aliases', () {
      // ignore: unnecessary_type_check
      final Schema schema = S.string(description: 'A title.');
      expect(schema.value['type'], 'string');
    });
  });
}
