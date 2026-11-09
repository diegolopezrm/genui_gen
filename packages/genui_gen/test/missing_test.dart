import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

final CatalogImplementation _catalog = CatalogImplementation(
  id: 'dev.dlsoft.test',
  components: [
    CatalogItem(
      name: 'ProductCard',
      schema: S.object(properties: {'title': CommonSchemas.dynamicString}),
      builder: (context, node, props, buildChild) => const SizedBox.shrink(),
    ),
  ],
  functions: [
    // A call that has not answered yet, as a slow one has not.
    GenUiClientFunction(
      name: 'loadTitle',
      description: 'Loads the title.',
      argumentSchema: S.object(properties: {}),
      body: (args, context) => null,
    ),
  ],
);

/// A `ProductCard` with [properties], resolved the way the renderer resolves
/// it, as the root of surface `s`, and the errors that surface reports.
///
/// Built without a processor, so a literal its schema would refuse can still
/// reach the component, as a stale or hand-built surface can.
({ComponentNode<ComponentImplementation> node, List<A2uiRendererError> errors})
resolve(Map<String, Object?> properties, {String id = 'card-1'}) {
  final surface = SurfaceModel<ComponentImplementation>(
    's',
    defaultCatalog: _catalog,
    rootId: id,
  );
  final resolver = NodeResolver<ComponentImplementation>(surface);
  // Teardowns run in reverse, so the resolver goes before its surface.
  addTearDown(surface.dispose);
  addTearDown(resolver.dispose);
  final errors = <A2uiRendererError>[];
  surface.onError.subscribe(errors.add);
  surface.componentsModel.addComponent(
    ComponentModel(id, 'ProductCard', properties),
  );
  return (node: resolver.rootNode.peek()!, errors: errors);
}

/// Lets an error dispatched on a surface arrive.
Future<void> delivered() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(genUiResetMissingReports);

  test('reports an omitted literal as VALIDATION_FAILED', () async {
    final resolved = resolve(const {});
    genUiReportMissing(resolved.node, 'ProductCard', 'title');
    await delivered();

    final A2uiRendererError error = resolved.errors.single;
    expect(error.code, 'VALIDATION_FAILED');
    expect(error.message, contains('ProductCard'));
    expect(error.message, contains('"title"'));
    expect(error.surfaceId, 's');
    expect(error.path, 'title');
  });

  test('does not report a path binding that resolves to null', () async {
    final resolved = resolve(const {
      'title': {'path': '/product/title'},
    });
    genUiReportMissing(resolved.node, 'ProductCard', 'title');
    await delivered();

    expect(resolved.errors, isEmpty);
  });

  test('does not report a function call binding', () async {
    final resolved = resolve(const {
      'title': {'call': 'loadTitle'},
    });
    genUiReportMissing(resolved.node, 'ProductCard', 'title');
    await delivered();

    expect(resolved.errors, isEmpty);
  });

  test('reports a literal of the wrong shape', () async {
    final resolved = resolve(const {
      'title': {'unexpected': 1},
    });
    genUiReportMissing(resolved.node, 'ProductCard', 'title');
    await delivered();

    expect(resolved.errors, hasLength(1));
  });

  test('reports once per component instance across rebuilds', () async {
    final first = resolve(const {});
    genUiReportMissing(first.node, 'ProductCard', 'title');
    genUiReportMissing(first.node, 'ProductCard', 'title');
    final second = resolve(const {}, id: 'card-2');
    genUiReportMissing(second.node, 'ProductCard', 'title');
    await delivered();

    expect(first.errors, hasLength(1));
    expect(second.errors, hasLength(1));
  });
}
