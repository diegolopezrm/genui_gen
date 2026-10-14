import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'support/surface.dart';

enum _Size { small, large }

/// A switch, hand-written the way generated code writes it: the value is read
/// through `props`, and written back through [genUiWriter].
final ComponentImplementation _toggle = ComponentImplementation(
  name: 'Toggle',
  schema: GenUiSchemas.component(
    description: 'A switch.',
    properties: {'value': GenUiSchemas.boolean()},
  ),
  builder: (context, node, props, buildChild) => Switch(
    value: props.boolean('value') ?? false,
    onChanged: genUiWriter<bool>(context, props, 'value'),
  ),
);

/// Writes an enum, which travels as its name.
final ComponentImplementation _sizer = ComponentImplementation(
  name: 'Sizer',
  schema: GenUiSchemas.component(
    description: 'Picks a size.',
    properties: {
      'size': GenUiSchemas.string(enumValues: ['small', 'large']),
    },
  ),
  builder: (context, node, props, buildChild) {
    final ValueChanged<_Size>? write = genUiWriter<_Size>(
      context,
      props,
      'size',
      encode: (value) => value.name,
    );
    return TextButton(
      onPressed: write == null ? null : () => write(_Size.large),
      child: Text(props.string('size') ?? 'none'),
    );
  },
);

@immutable
class _Row {
  const _Row(this.label);
  final String label;
}

/// Decodes a bound object the way generated code does, reporting through
/// [genUiMissingIn].
final ComponentImplementation _labelled = ComponentImplementation(
  name: 'Labelled',
  schema: GenUiSchemas.component(
    description: 'Shows the label of an object.',
    properties: {
      'row': GenUiSchemas.object(
        literal: S.object(
          properties: {'label': S.string()},
          required: ['label'],
        ),
      ),
    },
  ),
  builder: (context, node, props, buildChild) {
    final GenUiMissingFieldReporter report = genUiMissingIn(
      context,
      node,
      'row',
    );
    final Map<String, Object?> json =
        genUiAsObject(props.value('row')) ?? const {};
    final row = _Row(
      genUiAsString(json['label']) ??
          genUiMissingField<String>(report, 'label', '?'),
    );
    // A field of a nested object, as its decoder names it.
    if (json['owner'] case final Map<Object?, Object?> owner
        when owner['name'] == null) {
      genUiNestedField(report, 'owner')!('name');
    }
    return Text(row.label);
  },
);

CatalogImplementation _catalog() =>
    testCatalog(components: [_toggle, _sizer, _labelled]);

Switch _switch(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch));

void main() {
  group('genUiWriter', () {
    testWidgets('writes to the path the property is bound to', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        _catalog(),
        [
          {
            'id': 'root',
            'component': 'Toggle',
            'value': {'path': '/on'},
          },
        ],
        initialData: {'on': false},
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(surface.read('/on'), isTrue);
      expect(_switch(tester).value, isTrue);
    });

    testWidgets('gives nothing to write with for a literal', (tester) async {
      await TestSurface.pump(tester, _catalog(), [
        {'id': 'root', 'component': 'Toggle', 'value': true},
      ]);

      expect(_switch(tester).value, isTrue);
      expect(_switch(tester).onChanged, isNull);
    });

    testWidgets('writes an enum as its name', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        _catalog(),
        [
          {
            'id': 'root',
            'component': 'Sizer',
            'size': {'path': '/size'},
          },
        ],
        initialData: {'size': 'small'},
      );

      await tester.tap(find.text('small'));
      await tester.pump();
      expect(surface.read('/size'), 'large');
      expect(find.text('large'), findsOneWidget);
    });

    testWidgets('reports a write the data model rejects', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        _catalog(),
        [
          {
            'id': 'root',
            'component': 'Toggle',
            'value': {'path': '/count/on'},
          },
        ],
        initialData: {'count': 3},
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(surface.errors, hasLength(1));
      expect(surface.errors.single.code, isNotEmpty);
      expect(surface.read('/count'), 3);
    });
  });

  group('genUiMissingIn', () {
    testWidgets('reports a missing field of bound data once', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        _catalog(),
        [
          {
            'id': 'root',
            'component': 'Labelled',
            'row': {'path': '/row'},
          },
        ],
        initialData: {
          'row': {
            'owner': {'id': 1},
          },
        },
      );
      await tester.pump();

      expect(find.text('?'), findsOneWidget);
      expect(
        [for (final e in surface.errors) e.path],
        ['/row/label', '/row/owner/name'],
      );
      expect(surface.errors.first.code, 'VALIDATION_FAILED');
      expect(surface.errors.first.message, contains('"label"'));

      await surface.send([data('x', path: '/elsewhere')]);
      await surface.send([
        data({
          'owner': {'id': 2},
        }, path: '/row'),
      ]);
      await tester.pump();
      expect(surface.errors, hasLength(2));
    });

    testWidgets('stays quiet once the data is complete', (tester) async {
      final surface = await TestSurface.pump(
        tester,
        _catalog(),
        [
          {
            'id': 'root',
            'component': 'Labelled',
            'row': {'path': '/row'},
          },
        ],
        initialData: {
          'row': {'label': 'Groceries'},
        },
      );
      await tester.pump();

      expect(find.text('Groceries'), findsOneWidget);
      expect(surface.errors, isEmpty);
    });
  });
}
