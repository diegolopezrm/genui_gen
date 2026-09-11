// The end-to-end claim of `@GenUiWrites`: flipping the switch that the
// generated builder wired up puts the new value in the surface's data model,
// and the component reads it back from there.
import 'package:example/widgets/preference_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Future<void> pumpItem(
  WidgetTester tester, {
  required DataContext dataContext,
  required Map<String, Object?> data,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) =>
              preferenceRowCatalogItem.widgetBuilder(
                CatalogItemContext(
                  data: data,
                  id: 'pref-1',
                  type: 'PreferenceRow',
                  buildChild: (_, [_]) => const SizedBox.shrink(),
                  dispatchEvent: (_) {},
                  buildContext: context,
                  dataContext: dataContext,
                  getComponent: (_) => null,
                  getCatalogItem: (_) => null,
                  surfaceId: 'surface-1',
                  reportError: (_, _) {},
                ),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late InMemoryDataModel model;
  late DataContext dataContext;

  setUp(() {
    model = InMemoryDataModel();
    dataContext = DataContext(model, DataPath.root);
  });

  tearDown(() => model.dispose());

  testWidgets('the switch writes to the path the model bound', (tester) async {
    model.update(DataPath('/settings/notify'), false);
    await pumpItem(
      tester,
      dataContext: dataContext,
      data: <String, Object?>{
        'label': 'Weekly summary',
        'enabled': <String, Object?>{'path': '/settings/notify'},
      },
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(model.getValue<bool>(DataPath('/settings/notify')), isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('a literal still round-trips, through a path of its own', (
    tester,
  ) async {
    await pumpItem(
      tester,
      dataContext: dataContext,
      data: <String, Object?>{'label': 'Weekly summary', 'enabled': true},
    );

    // Nothing was bound, so the literal is what the switch starts from.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(model.getValue<bool>(DataPath('pref-1.enabled')), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
