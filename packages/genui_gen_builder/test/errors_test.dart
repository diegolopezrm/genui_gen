import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  test('unsupported parameter type', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, required this.color});
  final Object color;
}
'''),
      failsWith([
        'Unsupported parameter type `Object` for `Bad.color`',
        '@GenUiProp(ignore: true)',
        'lib/widget.dart',
      ]),
    );
  });

  test('unsupported list element type', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, required this.values});
  final List<int> values;
}
'''),
      failsWith(['Unsupported parameter type `List<int>` for `Bad.values`']),
    );
  });

  test('missing description', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: '  ')
class Bad extends StatelessWidget {
  const Bad({super.key});
}
'''),
      failsWith(['@GenUiWidget on `Bad` needs a non-empty `description`']),
    );
  });

  test('ignore on a required parameter', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, @GenUiProp(ignore: true) required this.title});
  final String title;
}
'''),
      failsWith([
        '`Bad.title` is marked @GenUiProp(ignore: true) but it is a required parameter',
      ]),
    );
  });

  test('unknown named constructor', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.', constructor: 'nope')
class Bad extends StatelessWidget {
  const Bad({super.key});
}
'''),
      failsWith(['expects a constructor named `nope`']),
    );
  });

  test('annotation on a class that is not a Widget', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad {
  const Bad({required this.title});
  final String title;
}
'''),
      failsWith(['@GenUiWidget on `Bad` requires a class that extends Widget']),
    );
  });

  test('annotation on an abstract class', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
abstract class Bad extends StatelessWidget {
  const Bad({super.key, required this.title});
  final String title;
}
'''),
      failsWith(['@GenUiWidget cannot be applied to abstract class `Bad`']),
    );
  });

  test('component name Text collides with the core catalog', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Text extends StatelessWidget {
  const Text({super.key, required this.child});
  final Widget child;
}
'''),
      failsWith(['Component name `Text` on `Text` collides']),
    );
  });

  test('private class without an explicit name', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class _Bad extends StatelessWidget {
  const _Bad({required this.title});
  final String title;
}
'''),
      failsWith(['`_Bad` is private', '@GenUiWidget(name: ...)']),
    );
  });

  test('ignored optional positional parameter followed by another', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad(this.a, [@GenUiProp(ignore: true) this.b = 1, this.c = 'x']);
  final String a;
  final int b;
  final String c;
}
'''),
      failsWith([
        '`Bad.b` is positional and cannot be left out of the schema',
        '`c` would shift into its slot',
      ]),
    );
  });

  test('ignored trailing optional positional parameter is fine', () async {
    final out = await generate('''
@GenUiWidget(description: 'Ok.')
class Ok extends StatelessWidget {
  const Ok(this.a, [this.c = 'x', @GenUiProp(ignore: true) this.b = 1]);
  final String a;
  final int b;
  final String c;
}
''');
    expect(
      out,
      contains(
        "Ok(v.string('a') ?? missing<String>('a', ''), v.string('c') ?? 'x')",
      ),
    );
  });

  test(
    'super formal inheriting a non-literal default across libraries',
    () async {
      await expectLater(
        generate(
          '''
@GenUiWidget(description: 'Bad.')
class Bad extends Base {
  const Bad({super.key, super.count});
}
''',
          imports: '$defaultImports\nimport "package:a/base.dart";\n',
          extraAssets: {
            'a|lib/base.dart': '''
import 'package:flutter/widgets.dart';
const _k = 3;
class Base extends StatelessWidget {
  const Base({super.key, this.count = _k});
  final int count;
}
''',
          },
        ),
        failsWith([
          '`Bad.count` inherits the default value `_k`',
          'package:a/base.dart',
          'Redeclare it as `this.count = <default>`',
        ]),
      );
    },
  );

  test('super formal inheriting a literal default across libraries', () async {
    final out = await generate(
      '''
@GenUiWidget(description: 'Ok.')
class Ok extends Base {
  const Ok({super.key, super.count});
}
''',
      imports: '$defaultImports\nimport "package:a/base.dart";\n',
      extraAssets: {
        'a|lib/base.dart': '''
import 'package:flutter/widgets.dart';
class Base extends StatelessWidget {
  const Base({super.key, this.count = 3});
  final int count;
}
''',
      },
    );
    expect(out, contains("count: v.number('count')?.toInt() ?? 3"));
  });

  test('two classes with the same lower-camel name', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'One.')
class HTTPCard extends StatelessWidget {
  const HTTPCard({super.key});
}

@GenUiWidget(description: 'Two.')
class HttpCard extends StatelessWidget {
  const HttpCard({super.key});
}
'''),
      failsWith([
        'Classes `HTTPCard` and `HttpCard` would both generate `httpCardCatalogItem`',
      ]),
    );
  });

  test('annotation on something that is not a class', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
enum Bad { a, b }
'''),
      failsWith(['@GenUiWidget can only be applied to classes']),
    );
  });

  test('@GenUiAction on a non-callback parameter', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, @GenUiAction() required this.title});
  final String title;
}
'''),
      failsWith(['@GenUiAction on `Bad.title` requires a `VoidCallback`']),
    );
  });

  test('invalid schema property name', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, @GenUiProp(name: 'has space') required this.title});
  final String title;
}
'''),
      failsWith(['Invalid property name `has space` for `Bad.title`']),
    );
  });

  test('duplicate schema property names', () async {
    await expectLater(
      generate('''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({
    super.key,
    required this.title,
    @GenUiProp(name: 'title') required this.heading,
  });
  final String title;
  final String heading;
}
'''),
      failsWith([
        'Property name `title` is used by both `Bad.title` and `Bad.heading`',
      ]),
    );
  });

  test('enum only visible through an import prefix', () async {
    await expectLater(
      generate(
        '''
@GenUiWidget(description: 'Bad.')
class Bad extends StatelessWidget {
  const Bad({super.key, required this.tone});
  final t.Tone tone;
}
''',
        imports: '$defaultImports\nimport "package:a/tone.dart" as t;\n',
        extraAssets: {'a|lib/tone.dart': 'enum Tone { calm, loud }'},
      ),
      failsWith(['Enum `Tone` used by `Bad.tone` is not visible unprefixed']),
    );
  });

  group('missing imports', () {
    const widget = '''
@GenUiWidget(description: 'Card.')
class Card extends StatelessWidget {
  const Card({super.key, required this.title, this.onTap});
  final String title;
  final VoidCallback? onTap;
}
''';

    test('genui missing', () async {
      await expectLater(
        generate(
          widget,
          imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui_gen/genui_gen.dart';
''',
        ),
        failsWith([
          'identifiers that are not in scope in package:a/widget.dart',
          "import 'package:genui/genui.dart';    // provides CatalogItem, A2uiSchemas, JsonMap",
        ]),
      );
    });

    test('genui_gen runtime missing', () async {
      await expectLater(
        generate(
          widget,
          imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart' show GenUiWidget;
import 'package:json_schema_builder/json_schema_builder.dart';
''',
        ),
        failsWith([
          "import 'package:genui_gen/genui_gen.dart';    // provides "
              'GenUiBindings, GenUiBinding, genUiActionHandler, '
              'genUiReportMissing',
        ]),
      );
    });

    test('genui imported only with a prefix', () async {
      await expectLater(
        generate(
          widget,
          imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart' as g;
import 'package:genui_gen/genui_gen.dart';
''',
        ),
        failsWith([
          "import 'package:genui/genui.dart';    // provides CatalogItem",
          '`package:genui/genui.dart` is imported with prefix `g`, but '
              'generated code needs its identifiers unprefixed',
        ]),
      );
    });

    test('schema alias S missing', () async {
      await expectLater(
        generate(
          widget,
          imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart' hide S, Schema;
''',
        ),
        failsWith([
          "import 'package:json_schema_builder/json_schema_builder.dart';    // provides S",
        ]),
      );
    });

    test('succeeds when S comes from json_schema_builder directly', () async {
      final out = await generate(
        widget,
        imports: '''
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart' hide S, Schema;
import 'package:json_schema_builder/json_schema_builder.dart';
''',
      );
      expect(out, contains('cardCatalogItem'));
    });
  });
  test('a name from the basic catalog warns but still generates', () async {
    final warnings = await generateWarnings('''
@GenUiWidget(description: 'A card of my own.')
class Card extends StatelessWidget {
  const Card({super.key, required this.title});
  final String title;
}
''');
    expect(
      warnings.single,
      allOf([
        contains('Component name `Card`'),
        contains('genui basic catalog item'),
        contains('@GenUiWidget(name: ...)'),
      ]),
    );
  });

  test('a name of its own warns about nothing', () async {
    final warnings = await generateWarnings('''
@GenUiWidget(description: 'A card of my own.')
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.title});
  final String title;
}
''');
    expect(warnings, isEmpty);
  });
}
