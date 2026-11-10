import 'package:test/test.dart';

import 'src/harness.dart';
import 'src/harness_a2ui.dart';

void main() {
  group('on a2ui_flutter', () {
    test('a genui_gen built on a2ui_flutter gets GenUiComponents', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''');
      expect(
        out,
        contains(
          'final GenUiComponent emptyCatalogItem = '
          "GenUiComponent(name: 'Empty', "
          "schema: GenUiSchemas.component(description: 'Empty.'), "
          'examples: [r\'\'\' [{"id":"root","component":"Empty"}]\'\'\'], '
          'builder: (context, node, props, buildChild) => Empty())',
        ),
      );
      expect(out, isNot(contains('CatalogItem(')));
      expect(out, isNot(contains('exampleData')));
    });

    test('the same widget still gets a CatalogItem on genui', () async {
      final out = await generate('''
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''');
      expect(
        out,
        contains('final CatalogItem emptyCatalogItem = CatalogItem('),
      );
    });

    test('scalars are read through ComponentProps', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Scalars.')
class Scalars extends StatelessWidget {
  const Scalars({
    super.key,
    required this.title,
    this.subtitle,
    this.price = 1,
    required this.quantity,
    this.limit,
    this.ratio,
    required this.enabled,
  });
  /// Shown at the top.
  final String title;
  final String? subtitle;
  final double price;
  final int quantity;
  final int? limit;
  final num? ratio;
  final bool enabled;
}
''');
      expect(
        out,
        contains(
          "'title': GenUiSchemas.string(description: 'Shown at the top.')",
        ),
      );
      expect(out, contains("'price': GenUiSchemas.number()"));
      expect(out, contains("'enabled': GenUiSchemas.boolean()"));
      expect(out, contains("required: ['title', 'quantity', 'enabled']"));
      expect(out, contains("title: props.string('title') ?? ''"));
      expect(out, contains("subtitle: props.string('subtitle'),"));
      expect(out, contains("price: props.number('price') ?? 1,"));
      expect(
        out,
        contains("quantity: (props.number('quantity') ?? 0).toInt()"),
      );
      expect(out, contains("limit: props.number('limit')?.toInt(),"));
      expect(out, contains("ratio: props.number('ratio'),"));
      expect(out, contains("enabled: props.boolean('enabled') ?? false"));
    });

    test('an enum is a dynamic string limited to its names', () async {
      final out = await generateA2ui('''
enum Size { small, large }

@GenUiWidget(description: 'Sized.')
class Sized extends StatelessWidget {
  const Sized({super.key, required this.size, this.sizes});
  final Size size;
  final List<Size>? sizes;
}
''');
      expect(
        out,
        contains("'size': GenUiSchemas.string(enumValues: ['small', 'large'])"),
      );
      expect(
        out,
        contains(
          "'sizes': GenUiSchemas.list(items: S.string(enumValues: "
          "['small', 'large']))",
        ),
      );
      expect(
        out,
        contains(
          "size: Size.values.asNameMap()[props.string('size')] ?? "
          'Size.values.first',
        ),
      );
      expect(
        out,
        contains(
          "sizes: genUiAsStringList(props.value('sizes'))?.map((name) => "
          'Size.values.asNameMap()[name]).nonNulls.toList()',
        ),
      );
    });

    test('children are nodes the builder renders with buildChild', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Frame.')
class Frame extends StatelessWidget {
  const Frame({
    super.key,
    required this.child,
    this.footer,
    this.children,
    @GenUiProp(template: true) this.rows = const [],
  });
  final Widget child;
  final Widget? footer;
  final List<Widget>? children;
  final List<Widget> rows;
}
''');
      expect(out, contains("'child': GenUiSchemas.componentId()"));
      expect(out, contains("'children': GenUiSchemas.componentIdList()"));
      expect(out, contains("'rows': GenUiSchemas.childList()"));
      expect(
        out,
        contains(
          "child: switch (props.child('child')) {final childNode? => "
          'buildChild(childNode), null => const SizedBox.shrink()}',
        ),
      );
      expect(
        out,
        contains(
          "footer: switch (props.child('footer')) {final childNode? => "
          'buildChild(childNode), null => null}',
        ),
      );
      expect(
        out,
        contains(
          "children: props['children'] == null ? null : "
          "props.children('children').map(buildChild).toList()",
        ),
      );
      expect(
        out,
        contains(
          "rows: props['rows'] == null ? const [] : "
          "props.children('rows').map(buildChild).toList()",
        ),
      );
    });

    test('an action is the closure a2ui_core resolved', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Tap.')
class Tap extends StatelessWidget {
  const Tap({super.key, this.onTap, required this.onLongPress});
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
}
''');
      expect(out, contains("'onTap': GenUiSchemas.action()"));
      expect(out, contains("onTap: props.action('onTap'),"));
      expect(
        out,
        contains("onLongPress: props.action('onLongPress') ?? () {}"),
      );
    });

    test('a writer writes through the binding of the property', () async {
      final out = await generateA2ui('''
enum Size { small, large }

@GenUiWidget(description: 'Toggle.')
class Toggle extends StatelessWidget {
  const Toggle({
    super.key,
    required this.value,
    @GenUiWrites('value') required this.onChanged,
    required this.size,
    @GenUiWrites('size') this.onSize,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final Size size;
  final ValueChanged<Size>? onSize;
}
''');
      expect(out, contains('bind it to a data path if you need to read'));
      // The example binds what the widget writes, since a literal there would
      // be a control the user cannot change, and the agent copies examples.
      expect(out, contains('"value":{"path":"/value"}'));
      expect(out, contains('"size":{"path":"/size"}'));
      expect(
        out,
        contains(
          "onChanged: genUiWriter<bool>(context, props, 'value') ?? (_) {}",
        ),
      );
      expect(
        out,
        contains(
          "onSize: genUiWriter<Size>(context, props, 'size', "
          'encode: (value) => value.name)',
        ),
      );
    });

    test('checks come from the props a2ui_core evaluated', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Field.')
class Field extends StatelessWidget {
  const Field({super.key, @GenUiChecked() this.error});
  final String? error;
}

@GenUiWidget(description: 'Submit.')
class Submit extends StatelessWidget {
  const Submit({super.key, @GenUiChecked() required this.enabled});
  final bool enabled;
}

@GenUiWidget(description: 'Both.')
class Both extends StatelessWidget {
  const Both({super.key, @GenUiChecked() required this.result});
  final GenUiCheckResult result;
}
''');
      expect(out, contains("'checks': GenUiSchemas.checks()"));
      expect(out, contains('error: props.validationErrors.firstOrNull'));
      expect(out, contains('enabled: props.isValid'));
      expect(
        out,
        contains(
          'result: GenUiCheckResult(isValid: props.isValid, '
          'message: props.validationErrors.firstOrNull)',
        ),
      );
    });

    test('a data object reports a missing field to the agent', () async {
      final out = await generateA2ui('''
@GenUiData()
class Item {
  const Item({required this.label});
  final String label;
}

@GenUiWidget(description: 'Items.')
class Items extends StatelessWidget {
  const Items({super.key, required this.item, this.items});
  final Item item;
  final List<Item>? items;
}
''');
      expect(
        out,
        contains("'item': GenUiSchemas.object(literal: itemGenUiSchema)"),
      );
      expect(
        out,
        contains("'items': GenUiSchemas.list(items: itemGenUiSchema)"),
      );
      expect(
        out,
        contains(
          "item: switch (genUiAsObject(props.value('item'))) "
          '{final Map<String, Object?> json => itemFromGenUiJson(json, '
          "genUiMissingIn(context, node, 'item')), "
          '_ => itemFromGenUiJson(const <String, Object?>{})}',
        ),
      );
      // `dart format` decides where the chain breaks, so only the pieces.
      expect(out, contains("items: genUiAsObjectList(props.value('items'))"));
      expect(
        out,
        contains(
          "itemFromGenUiJson(json, genUiMissingIn(context, node, 'items'))",
        ),
      );
      // The data class itself is the same on both renderers.
      expect(
        out,
        contains('final ObjectSchema itemGenUiSchema = ObjectSchema('),
      );
    });

    test('a map is a dynamic object with constrained values', () async {
      final out = await generateA2ui('''
@GenUiWidget(description: 'Counts.')
class Counts extends StatelessWidget {
  const Counts({super.key, this.counts});
  final Map<String, int>? counts;
}
''');
      expect(
        out,
        contains(
          "'counts': GenUiSchemas.object(literal: "
          'S.object(additionalProperties: S.integer()))',
        ),
      );
      expect(
        out,
        contains(
          "counts: genUiAsNumMap(props.value('counts'))?.map((key, value) => "
          'MapEntry(key, value.toInt()))',
        ),
      );
    });

    test('functions become FunctionImplementations', () async {
      final out = await generateA2ui('''
@GenUiFunction(description: 'Doubles it.')
int twice(int value) => value * 2;

@GenUiFunction(description: 'Later.')
Future<String> later({String name = 'x'}) async => name;

@GenUiFunction(description: 'Ticks.')
Stream<int> ticks() async* {}

@GenUiFunction(description: 'Nothing.')
void ping() {}
''');
      expect(
        out,
        contains(
          'final FunctionImplementation twiceGenUiFunction = '
          "GenUiClientFunction(name: 'twice'",
        ),
      );
      expect(
        out,
        contains(
          "argumentSchema: S.object(properties: {'value': "
          "GenUiSchemas.number()}, required: ['value'])",
        ),
      );
      expect(out, contains('returnType: A2uiReturnType.number'));
      expect(out, contains('GenUiClientFunction.async('));
      expect(out, contains('GenUiClientFunction.streaming('));
      expect(out, contains('returnType: A2uiReturnType.void_'));
      expect(out, isNot(contains('ClientFunctionReturnType')));
    });

    test('rejects a property name every component reserves', () async {
      for (final name in ['weight', 'accessibility', 'id', 'component']) {
        await expectLater(
          generateA2ui('''
@GenUiWidget(description: 'Heavy.')
class Heavy extends StatelessWidget {
  const Heavy({super.key, this.$name});
  final String? $name;
}
'''),
          failsWith(['`Heavy.$name`', 'reserves', '@GenUiProp(name:']),
          reason: name,
        );
      }
    });

    test('the same names are fine on genui', () async {
      final out = await generate('''
@GenUiWidget(description: 'Heavy.')
class Heavy extends StatelessWidget {
  const Heavy({super.key, this.weight});
  final double? weight;
}
''');
      expect(out, contains("'weight': A2uiSchemas.numberReference()"));
    });

    test(
      'rejects the names checks are written to on a checked widget',
      () async {
        await expectLater(
          generateA2ui('''
@GenUiWidget(description: 'Field.')
class Field extends StatelessWidget {
  const Field({super.key, @GenUiChecked() this.error, this.isValid});
  final String? error;
  final bool? isValid;
}
'''),
          failsWith(['`Field.isValid`', 'reserves']),
        );
      },
    );

    test('rejects a data object a2ui_core would read as an action', () async {
      await expectLater(
        generateA2ui('''
@GenUiData()
class Moment {
  const Moment({required this.event});
  final String event;
}

@GenUiWidget(description: 'Calendar.')
class Calendar extends StatelessWidget {
  const Calendar({super.key, this.moment});
  final Moment? moment;
}
'''),
        failsWith(['`Moment`', '`event`', 'as an action']),
      );
    });

    test('rejects a list a2ui_core would read as checks', () async {
      await expectLater(
        generateA2ui('''
@GenUiData()
class Rule {
  const Rule({required this.condition, required this.message});
  final String condition;
  final String message;
}

@GenUiWidget(description: 'Rules.')
class Rules extends StatelessWidget {
  const Rules({super.key, this.rules});
  final List<Rule>? rules;
}
'''),
        failsWith(['`Rule`', '`condition` and `message`', 'validation checks']),
      );
    });

    test('a nested data object keeps any name', () async {
      final out = await generateA2ui('''
@GenUiData()
class Moment {
  const Moment({required this.event});
  final String event;
}

@GenUiData()
class Day {
  const Day({required this.moment});
  final Moment moment;
}

@GenUiWidget(description: 'Calendar.')
class Calendar extends StatelessWidget {
  const Calendar({super.key, this.day});
  final Day? day;
}
''');
      expect(
        out,
        contains("'day': GenUiSchemas.object(literal: dayGenUiSchema)"),
      );
    });

    test('says isImplicitlyFlexible does nothing here', () async {
      final warnings = await generateWarnings(
        '''
@GenUiWidget(description: 'Wide.', isImplicitlyFlexible: true)
class Wide extends StatelessWidget {
  const Wide({super.key});
}
''',
        imports: a2uiImports,
        extraAssets: {'genui_gen|lib/genui_gen.dart': a2uiGenUiGenStub},
      );
      expect(warnings, anyElement(contains('`weight`')));
    });

    test('says a basic component name replaces the basic one', () async {
      final warnings = await generateWarnings(
        '''
@GenUiWidget(description: 'A card of my own.')
class Card extends StatelessWidget {
  const Card({super.key, required this.title});
  final String title;
}
''',
        imports: a2uiImports,
        extraAssets: {'genui_gen|lib/genui_gen.dart': a2uiGenUiGenStub},
      );
      expect(
        warnings.single,
        allOf([
          contains('Component name `Card`'),
          contains('replaces the basic component'),
          contains('@GenUiWidget(name: ...)'),
        ]),
      );
    });

    test('names the missing import for the a2ui_flutter types', () async {
      await expectLater(
        generateA2ui(
          '''
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''',
          imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui_gen/genui_gen.dart' show GenUiWidget;
''',
        ),
        failsWith([
          "import 'package:genui_gen/genui_gen.dart';",
          'GenUiComponent',
          'GenUiSchemas',
        ]),
      );
    });
  });
}
