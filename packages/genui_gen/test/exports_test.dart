import 'package:flutter/widgets.dart';
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

  group('re-exported renderer symbols', () {
    // The generated catalog file and every generated part name these, and
    // import nothing but this library to get them. This file imports neither
    // genui nor json_schema_builder for the same reason.
    test('a catalog can be built from this library alone', () {
      final JsonMap data = <String, Object?>{'title': 'A product.'};
      final catalog = Catalog([
        CatalogItem(
          name: 'Card',
          dataSchema: S.object(properties: {'title': S.string()}),
          widgetBuilder: (ctx) => const SizedBox.shrink(),
          exampleData: [() => '$data'],
        ),
      ], catalogId: 'dev.dlsoft.exports');

      expect(catalog.items.single.name, 'Card');
      expect(A2uiSchemas.stringReference().value, isNotEmpty);
    });

    test('a function can be declared from this library alone', () {
      final ClientFunction function = GenUiClientFunction(
        name: 'echo',
        description: 'Returns its argument.',
        argumentSchema: S.object(properties: {'value': S.string()}),
        returnType: ClientFunctionReturnType.string,
        body: (args, context) => args['value'],
      );

      expect(function.name, 'echo');
    });
  });
}
