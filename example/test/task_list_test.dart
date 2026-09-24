// A list the agent describes once and the data model repeats.
//
// The agent sends one row component and a path; the surface renders one row
// per entry, and new entries arriving in the data model add rows without the
// agent composing anything again.

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Future<SurfaceController> pumpTaskList(
  WidgetTester tester, {
  required Object rows,
  JsonMap? data,
}) async {
  final controller = SurfaceController(catalogs: [exampleCatalog]);
  addTearDown(controller.dispose);

  controller.handleMessage(
    core.UpdateComponentsMessage(
      surfaceId: 's',
      components: [
        {
          'id': 'root',
          'component': 'TaskList',
          'title': 'Today',
          'rows': rows,
        },
        {
          'id': 'task_row',
          'component': 'Text',
          'text': {'path': 'label'},
        },
      ],
    ),
  );
  controller.handleMessage(
    core.CreateSurfaceMessage(
      surfaceId: 's',
      catalogId: exampleCatalog.catalogId!,
    ),
  );
  if (data != null) {
    controller.handleMessage(
      core.UpdateDataModelMessage(surfaceId: 's', value: data),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Surface(surfaceContext: controller.contextFor('s'))),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('one row per entry in the data model', (tester) async {
    await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      data: {
        'tasks': [
          {'label': 'Call the dentist'},
          {'label': 'Renew the passport'},
        ],
      },
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Call the dentist'), findsOneWidget);
    expect(find.text('Renew the passport'), findsOneWidget);
  });

  testWidgets('a new entry adds a row, with no new surface', (tester) async {
    final controller = await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      data: {
        'tasks': [
          {'label': 'Call the dentist'},
        ],
      },
    );

    controller.handleMessage(
      core.UpdateDataModelMessage(
        surfaceId: 's',
        value: {
          'tasks': [
            {'label': 'Call the dentist'},
            {'label': 'Buy milk'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('a list of ids still works', (tester) async {
    await pumpTaskList(tester, rows: ['task_row']);

    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('an empty path renders the empty label', (tester) async {
    await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      data: {'tasks': <Object?>[]},
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
