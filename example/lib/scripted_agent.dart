import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

/// A stand-in for the agent, so the example runs with no key and no network.
///
/// A real agent composes these messages from a model. This one matches a few
/// words and answers with the same kind of thing a model would: a surface
/// built from the catalog, and the data it binds to. Everything downstream of
/// here — the surface, the bindings, the actions, the recording — is the real
/// machinery.
class ScriptedAgent {
  /// What the user can ask for, and what comes back.
  static const List<ScriptedTurn> turns = <ScriptedTurn>[
    ScriptedTurn(
      prompt: 'What is on my plate today?',
      keywords: <String>['plate', 'today', 'task', 'todo'],
      description: 'A list whose rows come from the data model.',
      components: <JsonMap>[
        {
          'id': 'root',
          'component': 'TaskList',
          'title': 'Today',
          'rows': {'componentId': 'task_row', 'path': '/tasks'},
        },
        {
          'id': 'task_row',
          'component': 'Text',
          'text': {'path': 'label'},
        },
      ],
      data: <String, Object?>{
        'tasks': <Object?>[
          {'label': 'Call the dentist'},
          {'label': 'Renew the passport'},
          {'label': 'Water the plants'},
        ],
      },
    ),
    ScriptedTurn(
      prompt: 'Let me change my notifications',
      keywords: <String>['notification', 'setting', 'preference', 'alert'],
      description:
          'A control that writes what the user chose back to the '
          'data model.',
      components: <JsonMap>[
        {
          'id': 'root',
          'component': 'Panel',
          'title': 'Notifications',
          'child': 'row',
          'actions': <String>['confirm'],
        },
        {
          'id': 'row',
          'component': 'PreferenceRow',
          'label': 'Weekly report',
          'detail': 'Sent every Monday morning',
          'enabled': {'path': '/notify/weekly'},
        },
        {
          'id': 'confirm',
          'component': 'Button',
          'child': 'confirm-label',
          'variant': 'primary',
          'action': {
            'event': {'name': 'save_preferences'},
          },
        },
        {'id': 'confirm-label', 'component': 'Text', 'text': 'Save'},
      ],
      data: <String, Object?>{
        'notify': <String, Object?>{'weekly': false},
      },
    ),
    ScriptedTurn(
      prompt: 'How did the store do this week?',
      keywords: <String>['store', 'sales', 'metric', 'week', 'report'],
      description: 'A table and a card, composed from two generated widgets.',
      components: <JsonMap>[
        {
          'id': 'root',
          'component': 'Column',
          'children': <String>['stat', 'table'],
        },
        {
          'id': 'stat',
          'component': 'StatTile',
          'label': 'Revenue',
          'value': 18420.5,
          'trend': 'up',
        },
        {
          'id': 'table',
          'component': 'MetricsTable',
          'title': 'By channel',
          'rows': <Object?>[
            {'label': 'Storefront', 'value': 12900.0, 'trend': 'up'},
            {'label': 'Marketplace', 'value': 4120.5, 'trend': 'flat'},
            {'label': 'Wholesale', 'value': 1400.0, 'trend': 'down'},
          ],
        },
      ],
      data: <String, Object?>{},
    ),
  ];

  /// The turn that best matches [prompt], or the first one.
  static ScriptedTurn answer(String prompt) {
    final String text = prompt.toLowerCase();
    for (final ScriptedTurn turn in turns) {
      if (turn.keywords.any(text.contains)) return turn;
    }
    return turns.first;
  }
}

/// One thing the scripted agent knows how to answer.
class ScriptedTurn {
  /// Creates a [ScriptedTurn].
  const ScriptedTurn({
    required this.prompt,
    required this.keywords,
    required this.description,
    required this.components,
    required this.data,
  });

  /// The prompt offered to the user as a suggestion.
  final String prompt;

  /// What a typed prompt is matched against.
  final List<String> keywords;

  /// What this turn is meant to show.
  final String description;

  /// The components of the surface.
  final List<JsonMap> components;

  /// The data model the surface binds to.
  final Map<String, Object?> data;

  /// The messages an agent would send for this turn.
  List<core.A2uiMessage> messages(
    String surfaceId,
    String catalogId,
  ) => <core.A2uiMessage>[
    core.UpdateComponentsMessage(surfaceId: surfaceId, components: components),
    core.CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
    if (data.isNotEmpty)
      core.UpdateDataModelMessage(surfaceId: surfaceId, value: data),
  ];
}
