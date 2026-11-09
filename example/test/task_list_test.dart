// A list the agent describes once and the data model repeats.
//
// The agent sends one row component and a path; the surface renders one row
// per entry, and new entries arriving in the data model add rows without the
// agent composing anything again.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final String _version = A2uiProtocolVersion.v0_9.jsonValue;

Future<MessageProcessor<ComponentImplementation>> pumpTaskList(
  WidgetTester tester, {
  required Object rows,
  Map<String, Object?>? data,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [exampleCatalog],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);

  processor.processMessages([
    {
      'version': _version,
      'createSurface': {'surfaceId': 's', 'catalogId': exampleCatalog.id},
    },
    if (data != null)
      {
        'version': _version,
        'updateDataModel': {'surfaceId': 's', 'value': data},
      },
    {
      'version': _version,
      'updateComponents': {
        'surfaceId': 's',
        'components': [
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
      },
    },
  ]);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: A2uiSurface(surface: processor.model.getSurface('s')!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return processor;
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
    final processor = await pumpTaskList(
      tester,
      rows: {'componentId': 'task_row', 'path': '/tasks'},
      data: {
        'tasks': [
          {'label': 'Call the dentist'},
        ],
      },
    );

    processor.processMessages({
      'version': _version,
      'updateDataModel': {
        'surfaceId': 's',
        'value': {
          'tasks': [
            {'label': 'Call the dentist'},
            {'label': 'Buy milk'},
          ],
        },
      },
    });
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
