import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

/// A catalog function of the kind an app would add: it computes something the
/// data model does not hold.
final ClientFunction initials = GenUiClientFunction(
  name: 'initials',
  description: 'Returns the initials of a full name.',
  argumentSchema: S.object(
    properties: {'name': S.string(description: 'A full name.')},
    required: ['name'],
  ),
  returnType: ClientFunctionReturnType.string,
  body: (args, context) {
    final String name = genUiAsString(args['name']) ?? '';
    return name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
  },
);

void main() {
  testWidgets('a generated function answers a {"call": ...} property', (
    tester,
  ) async {
    final catalog = BasicCatalogItems.asCatalog().copyWith(
      catalogId: 'test',
      newFunctions: [initials],
    );
    final controller = SurfaceController(catalogs: [catalog]);
    addTearDown(controller.dispose);

    controller.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: 's',
        components: [
          {
            'id': 'root',
            'component': 'Text',
            'text': {
              'call': 'initials',
              'args': {
                'name': {'path': '/user/name'},
              },
            },
          },
        ],
      ),
    );
    controller.handleMessage(
      core.CreateSurfaceMessage(surfaceId: 's', catalogId: 'test'),
    );
    controller.handleMessage(
      core.UpdateDataModelMessage(
        surfaceId: 's',
        value: {
          'user': {'name': 'Ada Lovelace'},
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Surface(surfaceContext: controller.contextFor('s')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AL'), findsOneWidget);
  });

  test('the function reaches the exported catalog document', () {
    final catalog = Catalog(const [], catalogId: 'test', functions: [initials]);
    final json = genUiCatalogJson(catalog);
    final functions = json['functions'] as Map<String, Object?>?;
    expect(functions, isNotNull);
    expect(functions!.keys, contains('initials'));
  });
}
