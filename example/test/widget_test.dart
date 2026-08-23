import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog contains the four generated items', (tester) async {
    final names = exampleCatalog.items.map((item) => item.name).toSet();
    expect(
      names,
      containsAll(<String>['ProductCard', 'StatTile', 'TagRow', 'Panel']),
    );
  });

  testWidgets('every generated item has a parseable example', (tester) async {
    for (final name in const ['ProductCard', 'StatTile', 'TagRow', 'Panel']) {
      final item = exampleCatalog.items.singleWhere((i) => i.name == name);
      expect(item.exampleData, isNotEmpty, reason: name);
      for (final example in item.exampleData) {
        expect(example(), contains('"id": "root"'), reason: name);
      }
    }
  });

  testWidgets('the gallery page renders', (tester) async {
    await tester.pumpWidget(const GenUiGenExampleApp());
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('genui_gen example'), findsOneWidget);
  });
}
