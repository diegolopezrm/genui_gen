import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:genui_gen_builder/builder.dart';
import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  test('generated file has the header and part-of directive', () async {
    final out = await generateRaw('''
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''');
    expect(out, startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND'));
    expect(out, contains('// ignore_for_file: type=lint'));
    expect(out, contains("part of 'widget.dart';"));
    expect(out, contains('/// Generated [CatalogItem] for [Empty].'));
  });

  test('warns and writes nothing without a part directive', () async {
    final logs = <String>[];
    final result = await testBuilder(
      genUiGenBuilder(const BuilderOptions({})),
      {
        ...stubAssets,
        'a|lib/widget.dart':
            '''
$defaultImports
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''',
      },
      rootPackage: 'a',
      onLog: (record) => logs.add(record.message),
    );
    expect(result.succeeded, isTrue);
    expect(
      result.readerWriter.testing.exists(AssetId('a', 'lib/widget.genui.dart')),
      isFalse,
    );
    expect(logs, anyElement(contains('must be included as a part directive')));
  });

  test('widgets without properties build directly', () async {
    final out = await generate('''
@GenUiWidget(description: 'Empty.')
class Empty extends StatelessWidget {
  const Empty({super.key});
}
''');
    expect(out, contains("dataSchema: S.object(description: 'Empty.')"));
    expect(out, contains('widgetBuilder: (ctx) => Empty()'));
    expect(out, contains('[{"id":"root","component":"Empty"}]'));
    expect(out, isNot(contains('JsonMap')));
  });

  test('name, isImplicitlyFlexible and constructor overrides', () async {
    final out = await generate('''
@GenUiWidget(
  name: 'Gallery',
  description: 'A gallery.',
  constructor: 'compact',
  isImplicitlyFlexible: true,
)
class ImageGallery extends StatelessWidget {
  const ImageGallery({super.key, required this.urls, this.dense = false});
  const ImageGallery.compact({super.key, required this.urls}) : dense = true;

  final List<String> urls;
  final bool dense;
}
''');
    expect(out, contains('final CatalogItem imageGalleryCatalogItem'));
    expect(out, contains("name: 'Gallery'"));
    expect(out, contains('isImplicitlyFlexible: true'));
    expect(out, contains("'urls': A2uiSchemas.stringArrayReference()"));
    expect(out, isNot(contains("'dense'")));
    expect(out, contains('ImageGallery.compact('));
    expect(
      out,
      contains(
        "urls: v.stringList('urls') ?? missing<List<String>>('urls', const <String>[])",
      ),
    );
    expect(out, contains('"component":"Gallery"'));
    expect(out, contains('"urls":["Alpha","Beta"]'));
  });

  test('positional parameters are passed positionally', () async {
    final out = await generate('''
@GenUiWidget(description: 'Label.')
class Label extends StatelessWidget {
  const Label(this.text, this.size, {super.key, this.bold = false});
  final String text;
  final int? size;
  final bool bold;
}
''');
    expect(
      out,
      contains(
        "Label(v.string('text') ?? missing<String>('text', ''), "
        "v.number('size')?.toInt(), bold: v.boolean('bold') ?? false)",
      ),
    );
  });

  test('ignored parameters are left out', () async {
    final out = await generate('''
@GenUiWidget(description: 'Ignores.')
class Ignores extends StatelessWidget {
  const Ignores({
    super.key,
    required this.title,
    @GenUiProp(ignore: true) this.padding = const Object(),
    this.decoration,
  });
  final String title;
  final Object padding;
  @GenUiProp(ignore: true)
  final Object? decoration;
}
''');
    expect(out, contains("'title': A2uiSchemas.stringReference()"));
    expect(out, isNot(contains('padding')));
    expect(out, isNot(contains('decoration')));
  });

  test('annotations on the backing field are honoured', () async {
    final out = await generate('''
@GenUiWidget(description: 'Field annotations.')
class FieldAnnotated extends StatelessWidget {
  const FieldAnnotated({super.key, required this.title});

  @GenUiProp(name: 'heading', description: 'From the field.')
  final String title;
}
''');
    expect(
      out,
      contains(
        "'heading': A2uiSchemas.stringReference(description: 'From the field.')",
      ),
    );
    expect(out, contains("title: v.string('heading')"));
  });

  test('multiple annotated classes in one file each get an item', () async {
    final out = await generate('''
@GenUiWidget(description: 'One.')
class One extends StatelessWidget {
  const One({super.key, required this.a});
  final String a;
}

@GenUiWidget(description: 'Two.')
class Two extends StatelessWidget {
  const Two({super.key, required this.b});
  final int b;
}
''');
    expect(out, contains('final CatalogItem oneCatalogItem'));
    expect(out, contains('final CatalogItem twoCatalogItem'));
  });

  test('classes without the annotation are skipped', () async {
    final out = await generate('''
@GenUiWidget(description: 'One.')
class One extends StatelessWidget {
  const One({super.key});
}

class Plain extends StatelessWidget {
  const Plain({super.key, required this.anything});
  final Object anything;
}
''');
    expect(out, contains('oneCatalogItem'));
    expect(out, isNot(contains('plainCatalogItem')));
  });

  test('string samples follow naming hints', () async {
    final out = await generate('''
@GenUiWidget(description: 'Contact.')
class Contact extends StatelessWidget {
  const Contact({
    super.key,
    required this.email,
    required this.website,
    this.avatarUrl,
  });
  final String email;
  final String website;
  final String? avatarUrl;
}
''');
    expect(out, contains('"email":"user@example.com"'));
    expect(out, contains('"website":"Sample website"'));
    expect(
      out,
      contains('"avatarUrl":"https://picsum.photos/seed/genui_gen/400/225"'),
    );
  });

  test('long descriptions are split into adjacent string literals', () async {
    final out = await generate('''
@GenUiWidget(
  description:
      'A card that presents a single product with its name, price in USD '
      'and an optional image. Use it to show one item of a catalog.',
)
class Card extends StatelessWidget {
  const Card({super.key, required this.title});

  /// The product name shown as the card headline, truncated to a single line.
  final String title;
}
''');
    expect(
      out,
      contains(
        "description: 'A card that presents a single product with its name, "
        "price ' 'in USD and an optional image. Use it to show one item of a ' "
        "'catalog.'",
      ),
    );
    expect(
      out,
      contains(
        "description: 'The product name shown as the card headline, "
        "truncated to a ' 'single line.'",
      ),
    );
  });
}
