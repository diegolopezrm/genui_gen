// A list the agent describes once and the data model repeats.
//
// The agent sends one row component and a path; the surface renders one row
// per entry, and new entries arriving in the data model add rows without the
// agent composing anything again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

Future<ExampleSurface> pumpTaskList(
  WidgetTester tester, {
  required Object rows,
  JsonMap? initialData,
}) => ExampleSurface.pump(tester, [
  {'id': 'root', 'component': 'TaskList', 'title': 'Today', 'rows': rows},
  {
    'id': 'task_row',
    'component': 'Text',
    'text': {'path': 'label'},
  },
], initialData: initialData);

void main() {
  testWidgets('one row per entry in the data model', (tester) async {
    await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      initialData: {
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
    final ExampleSurface surface = await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      initialData: {
        'tasks': [
          {'label': 'Call the dentist'},
        ],
      },
    );

    await surface.send([
      data([
        {'label': 'Call the dentist'},
        {'label': 'Buy milk'},
      ], path: '/tasks'),
    ]);
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
      initialData: {'tasks': <Object?>[]},
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
