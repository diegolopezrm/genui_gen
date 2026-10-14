import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

import 'support/surface.dart';

/// Records the props a2ui_core resolved for it, and renders its children.
final class _Probe {
  ComponentProps? props;

  late final ComponentImplementation implementation = ComponentImplementation(
    name: 'Probe',
    schema: GenUiSchemas.component(
      description: 'Every shape a generated property can take.',
      properties: {
        'text': GenUiSchemas.string(),
        'size': GenUiSchemas.string(enumValues: ['small', 'large']),
        'count': GenUiSchemas.number(),
        'on': GenUiSchemas.boolean(),
        'tags': GenUiSchemas.stringList(),
        'values': GenUiSchemas.list(items: S.number()),
        'item': GenUiSchemas.object(
          literal: S.object(properties: {'label': S.string()}),
        ),
        'child': GenUiSchemas.componentId(),
        'ids': GenUiSchemas.componentIdList(),
        'rows': GenUiSchemas.childList(),
        'onTap': GenUiSchemas.action(),
        'checks': GenUiSchemas.checks(),
      },
    ),
    builder: (context, node, props, buildChild) {
      this.props = props;
      return Column(
        children: [
          if (props.child('child') case final child?) buildChild(child),
          ...props.children('ids').map(buildChild),
          ...props.children('rows').map(buildChild),
        ],
      );
    },
  );
}

Map<String, Object?> _text(String id, Object? text) => {
  'id': id,
  'component': 'Text',
  'text': text,
};

void main() {
  testWidgets('each shape reaches the builder as what generated code reads', (
    tester,
  ) async {
    final probe = _Probe();
    final surface = await TestSurface.pump(
      tester,
      testCatalog(components: [probe.implementation]),
      [
        {
          'id': 'root',
          'component': 'Probe',
          'text': {'path': '/text'},
          'size': 'large',
          'count': {'path': '/count'},
          'on': true,
          'tags': ['a', 'b'],
          'values': {'path': '/values'},
          'item': {'path': '/item'},
          'child': 'single',
          'ids': ['first', 'second'],
          'rows': {'componentId': 'row', 'path': '/rows'},
          'onTap': {
            'event': {'name': 'tapped'},
          },
          'checks': [
            {
              'condition': {
                'call': 'required',
                'args': {
                  'value': {'path': '/text'},
                },
              },
              'message': 'Say something.',
            },
          ],
        },
        _text('single', 'Single'),
        _text('first', 'First'),
        _text('second', 'Second'),
        _text('row', {'path': 'name'}),
      ],
      initialData: {
        'text': 'Hello',
        'count': 3,
        'values': [1, 2.5],
        'item': {'label': 'Milk'},
        'rows': [
          {'name': 'Row one'},
          {'name': 'Row two'},
        ],
      },
    );
    final ComponentProps props = probe.props!;

    // Dynamic values arrive as bindings, writable when bound to a path.
    expect(props['text'], isA<WritableBinding<Object?>>());
    expect(props.string('text'), 'Hello');
    expect(props['size'], isA<ResolvedBinding<Object?>>());
    expect(props.string('size'), 'large');
    expect(props.number('count'), 3);
    expect(props.boolean('on'), isTrue);
    expect(props.value('tags'), ['a', 'b']);
    expect(props.value('values'), [1, 2.5]);
    expect(props.value('item'), {'label': 'Milk'});
    expect(props.writable('item'), isNotNull);

    // Children arrive as nodes, a template expanded over its path.
    expect(props.child('child'), isNotNull);
    expect(props.children('ids'), hasLength(2));
    expect(props.children('rows'), hasLength(2));
    for (final text in ['Single', 'First', 'Second', 'Row one', 'Row two']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    // An action arrives as a closure that dispatches it.
    await props.action('onTap')!();
    expect([for (final a in surface.actions) a.name], ['tapped']);

    // The checks arrive evaluated.
    expect(props.isValid, isTrue);
    await surface.send([data('', path: '/text')]);
    expect(probe.props!.isValid, isFalse);
    expect(probe.props!.validationErrors, ['Say something.']);
  });

  test('a description replaces the shared one and keeps the marker', () {
    final Map<String, Object?> value = GenUiSchemas.string(
      description: 'The title.',
    ).value;
    expect(value['description'], 'The title.');
    expect(value['commonTypesRef'], endsWith('/DynamicString'));
    expect(
      CommonSchemas.dynamicString.value['description'],
      isNot('The title.'),
    );
  });

  test('a component takes the properties every basic component takes', () {
    final Map<String, Object?> value = GenUiSchemas.component(
      description: 'A card.',
      properties: {'title': GenUiSchemas.string()},
      required: ['title'],
    ).value;
    final properties = value['properties']! as Map<String, Object?>;
    expect(properties.keys, ['title', 'accessibility', 'weight']);
    expect(value['required'], ['title']);
    expect(value['additionalProperties'], isFalse);
  });
}
