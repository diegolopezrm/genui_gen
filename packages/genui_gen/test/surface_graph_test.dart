import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/inspector.dart';

typedef JsonMap = Map<String, Object?>;

/// A surface holding [components], composed against the basic catalog.
///
/// The processor checks each component against its schema, but not the
/// surface as a graph, since it is given no validation config: a surface the
/// agent is still building, or one it got wrong, is what the graph reads.
SurfaceModel<ComponentImplementation> _surface(List<JsonMap> components) {
  final CatalogImplementation catalog = basicCatalog();
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [catalog],
    defaultVersion: A2uiProtocolVersion.v0_9,
  );
  addTearDown(processor.dispose);
  processor.processMessages(<Object?>[
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': 's', 'catalogId': catalog.id},
    },
    if (components.isNotEmpty)
      {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': 's', 'components': components},
      },
  ]);
  return processor.model.getSurface('s')!;
}

void main() {
  group('GenUiSurfaceGraph', () {
    test('reads the tree out of the component definitions', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': ['heading', 'card'],
          },
          {'id': 'heading', 'component': 'Text', 'text': 'Storage'},
          {'id': 'card', 'component': 'Card', 'child': 'body'},
          {'id': 'body', 'component': 'Text', 'text': 'Nearly full'},
        ]),
      );

      expect(graph.hasRoot, isTrue);
      expect(graph.order, ['root', 'heading', 'card', 'body']);
      expect(graph.childrenOf('root'), ['heading', 'card']);
      expect(graph.childrenOf('card'), ['body']);
      expect(graph.depthOf('body'), 2);
      expect(graph.unreachable, isEmpty);
      expect(graph.cyclic, isEmpty);
    });

    test('reads the paths each component is bound to', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': ['toggle', 'total'],
          },
          {
            'id': 'toggle',
            'component': 'CheckBox',
            'label': 'Notify me',
            'value': {'path': '/on'},
          },
          {
            'id': 'total',
            'component': 'Text',
            'text': {'path': '/cart/total'},
          },
        ]),
      );

      expect(graph.pathsOf('toggle'), ['/on']);
      expect(graph.pathsOf('total'), ['/cart/total']);
      // A literal is not a binding.
      expect(graph.pathsOf('root'), isEmpty);
      expect(graph.pathBindings, {
        '/on': {'toggle'},
        '/cart/total': {'total'},
      });
    });

    test('a template is both a child and a binding', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/items'},
          },
          {
            'id': 'row',
            'component': 'Text',
            'text': {'path': 'name'},
          },
        ]),
      );

      // The repeated component is reached once, not twice: the id arrives
      // under `componentId` and must not be counted again as a string.
      expect(graph.childrenOf('root'), ['row']);
      // The holder watches the list to know how many rows there are.
      expect(graph.pathsOf('root'), ['/items']);
      // And the row reads `name` inside whichever row it is rendering, which
      // is every one of them.
      expect(graph.pathsOf('row'), ['/items/*/name']);
      expect(graph.unreachable, isEmpty);
    });

    test('an absolute path inside a template escapes the row', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': {'componentId': 'row', 'path': '/items'},
          },
          {
            'id': 'row',
            'component': 'Column',
            'children': ['name', 'currency'],
          },
          {
            'id': 'name',
            'component': 'Text',
            'text': {'path': 'name'},
          },
          {
            'id': 'currency',
            'component': 'Text',
            // Written with a leading slash, so it is the same value in every
            // row rather than one per row.
            'text': {'path': '/settings/currency'},
          },
        ]),
      );

      // Nesting carries down the tree, not just to the repeated component.
      expect(graph.pathsOf('name'), ['/items/*/name']);
      expect(graph.pathsOf('currency'), ['/settings/currency']);
    });

    test('a child nothing created is dangling, not an edge', () {
      // 'chart' is a child reference the agent made up. The catalog's schema
      // says `children` holds component ids, so it is read as one, and
      // reported as the hole it leaves.
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': ['heading', 'chart'],
          },
          {'id': 'heading', 'component': 'Text', 'text': 'Storage'},
        ]),
      );

      expect(graph.childrenOf('root'), ['heading']);
      expect(graph.order, ['root', 'heading']);
      expect(graph.dangling, {
        'root': {'chart'},
      });
      expect(
        graph.describe(),
        contains('Names components that do not exist: chart (in root)'),
      );
    });

    test('text that matches an id is not a child', () {
      // The schema says `text` is a string to show, so it stays one even when
      // it happens to spell a component's id.
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': ['heading', 'card'],
          },
          {'id': 'heading', 'component': 'Text', 'text': 'card'},
          {'id': 'card', 'component': 'Card', 'child': 'body'},
          {'id': 'body', 'component': 'Text', 'text': 'Nearly full'},
        ]),
      );

      expect(graph.childrenOf('heading'), isEmpty);
      expect(graph.dangling, isEmpty);
    });

    test('flags a component nothing reaches', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {
            'id': 'root',
            'component': 'Column',
            'children': ['heading'],
          },
          {'id': 'heading', 'component': 'Text', 'text': 'Storage'},
          {'id': 'stray', 'component': 'Text', 'text': 'Left over'},
        ]),
      );

      expect(graph.unreachable, ['stray']);
      expect(graph.depthOf('stray'), isNull);
      expect(graph.describe(), contains('never reached: stray'));
    });

    test('flags a component that contains itself, without hanging', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {'id': 'root', 'component': 'Card', 'child': 'inner'},
          {'id': 'inner', 'component': 'Card', 'child': 'root'},
        ]),
      );

      expect(graph.cyclic, ['root']);
      expect(graph.order, ['root', 'inner']);
      expect(graph.describe(), contains('Contains itself: root'));
    });

    test('says so when there is no root', () {
      final graph = GenUiSurfaceGraph.of(
        _surface(<JsonMap>[
          {'id': 'heading', 'component': 'Text', 'text': 'Storage'},
        ]),
      );

      expect(graph.hasRoot, isFalse);
      expect(graph.order, isEmpty);
      expect(graph.unreachable, ['heading']);
      expect(graph.describe(), contains('nothing renders'));
    });

    test('an empty surface describes itself without inventing findings', () {
      final graph = GenUiSurfaceGraph.of(_surface(<JsonMap>[]));

      expect(graph.describe(), contains('0 components on s'));
      expect(graph.cyclic, isEmpty);
    });
  });
}
