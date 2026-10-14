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
    // a2ui_flutter nor json_schema_builder for the same reason.
    test('a catalog can be built from this library alone', () {
      final catalog = CatalogImplementation(
        id: 'dev.dlsoft.exports',
        components: [
          ComponentImplementation(
            name: 'Card',
            schema: GenUiSchemas.component(
              description: 'A card.',
              properties: {'title': GenUiSchemas.string()},
            ),
            builder: (context, node, props, buildChild) =>
                Text(props.string('title') ?? ''),
          ),
        ],
      );

      expect(catalog.components.keys.single, 'Card');
      expect(CommonSchemas.dynamicString.value, isNotEmpty);
    });

    test('a function can be declared from this library alone', () {
      final FunctionImplementation function = GenUiClientFunction(
        name: 'echo',
        description: 'Returns its argument.',
        argumentSchema: S.object(properties: {'value': S.string()}),
        returnType: A2uiReturnType.string,
        body: (args, context) => args['value'],
      );

      expect(function.name, 'echo');
    });
  });
}
