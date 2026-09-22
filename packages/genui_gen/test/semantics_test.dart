import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart' show S;
import 'package:genui_gen/testing.dart';

/// A catalog item whose example renders a labelled button and a line of text.
final CatalogItem _panel = CatalogItem(
  name: 'Panel',
  dataSchema: S.object(
    description: 'A panel.',
    properties: {'title': S.string()},
    required: ['title'],
  ),
  exampleData: [
    () => r'''
[
  {"id": "root", "component": "Panel", "title": "Storage"}
]''',
  ],
  widgetBuilder: (ctx) {
    final title = (ctx.data as JsonMap)['title']! as String;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        ElevatedButton(onPressed: () {}, child: const Text('Manage')),
      ],
    );
  },
);

final Catalog _catalog = Catalog([_panel], catalogId: 'dev.dlsoft.test');

Future<List<GenUiSemanticNode>> record(WidgetTester tester) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GenUiExampleSurface(catalog: _catalog, item: _panel),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final nodes = genUiRenderedSemantics();
  handle.dispose();
  return nodes;
}

void main() {
  group('genUiSemantics', () {
    testWidgets('reports what a user moves through, in order', (tester) async {
      final nodes = await record(tester);

      expect(nodes.map((node) => node.role), ['text', 'button']);
      expect(nodes.map((node) => node.name), ['Storage', 'Manage']);
    });

    testWidgets('keeps the action on the node that carries the name', (
      tester,
    ) async {
      final nodes = await record(tester);

      expect(nodes.last.actions, contains('tap'));
    });

    testWidgets('leaves out the nodes a platform adds to lay things out', (
      tester,
    ) async {
      final nodes = await record(tester);

      // MaterialApp and Scaffold build several nodes of their own around the
      // surface; none of them is something a screen reader user stops on.
      expect(nodes, hasLength(2));
    });
  });

  group('genUiSemanticsDiff', () {
    const a = GenUiSemanticNode(role: 'text', name: 'Storage');
    const b = GenUiSemanticNode(role: 'button', name: 'Manage');

    test('is null when the two agree', () {
      expect(genUiSemanticsDiff([a, b], [a, b]), isNull);
    });

    test('names the position that changed', () {
      final difference = genUiSemanticsDiff(
        [a, b],
        [a, const GenUiSemanticNode(role: 'text', name: 'Manage')],
      );

      expect(difference, contains('[1]'));
      expect(difference, contains('"role":"button"'));
      expect(difference, contains('"role":"text"'));
    });

    test('reports a node that went missing', () {
      expect(genUiSemanticsDiff([a, b], [a]), contains('(nothing)'));
    });
  });

  group('genUiSemanticsGolden', () {
    late Directory directory;
    late File golden;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('genui_gen_golden');
      golden = File('${directory.path}/semantics.json');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    testWidgets('records the file when there is none', (tester) async {
      final recorded = {'Panel': await record(tester)};

      expect(genUiSemanticsGolden(recorded, golden), isNull);
      expect(golden.existsSync(), isTrue);
      expect(golden.readAsStringSync(), contains('"name": "Storage"'));
    });

    testWidgets('passes against what it recorded', (tester) async {
      final recorded = {'Panel': await record(tester)};
      genUiSemanticsGolden(recorded, golden);

      expect(genUiSemanticsGolden(recorded, golden), isNull);
    });

    testWidgets('fails when a component stops exposing what it did', (
      tester,
    ) async {
      final recorded = {'Panel': await record(tester)};
      genUiSemanticsGolden(recorded, golden);

      final difference = genUiSemanticsGolden({
        'Panel': [recorded['Panel']!.first],
      }, golden);

      expect(difference, contains('Panel'));
      expect(difference, contains('GENUI_UPDATE_GOLDENS'));
    });

    testWidgets('fails when a component appears or disappears', (tester) async {
      final recorded = {'Panel': await record(tester)};
      genUiSemanticsGolden(recorded, golden);

      expect(
        genUiSemanticsGolden({...recorded, 'Tile': const []}, golden),
        contains('Tile is new'),
      );
      expect(
        genUiSemanticsGolden(const {}, golden),
        contains('was not recorded'),
      );
    });

    testWidgets('re-records when asked to', (tester) async {
      final recorded = {'Panel': await record(tester)};
      genUiSemanticsGolden(recorded, golden);
      final trimmed = {
        'Panel': [recorded['Panel']!.first],
      };

      expect(genUiSemanticsGolden(trimmed, golden, update: true), isNull);
      expect(genUiSemanticsGolden(trimmed, golden), isNull);
    });
  });
}
