import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';

import '../main.dart';
import '../scripted_agent.dart';

/// The loop the package exists for: a request, a surface the agent composed
/// from the catalog, and whatever the user does with it coming back.
///
/// The agent here is scripted, so this runs with no key and no network. What
/// is real is everything after it: the messages, the surface, the bindings,
/// the actions, and the recording of all three.
class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  static const String _surfaceId = 'session';

  late SurfaceController _controller;
  late GenUiTraceRecorder _recorder;
  final TextEditingController _prompt = TextEditingController();
  final List<_Entry> _log = <_Entry>[];
  ScriptedTurn? _turn;
  int _sessions = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _controller.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _start() {
    _controller = SurfaceController(catalogs: [exampleCatalog]);
    _recorder = GenUiTraceRecorder.attach(
      _controller,
      catalogId: exampleCatalog.catalogId,
      notes: const {'source': 'genui_gen example, session tab'},
    );
    _controller.onSubmit.listen(_onSubmit);
  }

  void _onSubmit(ChatMessage message) {
    final String text = message.parts.uiInteractionParts
        .map((part) => part.interaction)
        .join('\n');
    if (text.isEmpty) return;
    setState(() => _log.add(_Entry.fromApp(text)));
    recordedTrace.value = _recorder.build();
  }

  void _ask(String prompt) {
    final ScriptedTurn turn = ScriptedAgent.answer(prompt);
    // A new surface per turn, so the ids of the previous one are free again.
    _sessions++;
    final String surfaceId = '$_surfaceId-$_sessions';

    setState(() {
      _log
        ..add(_Entry.fromUser(prompt))
        ..add(_Entry.fromAgent(turn.description));
      _turn = turn;
    });

    for (final message in turn.messages(surfaceId, exampleCatalog.catalogId!)) {
      _recorder.handleMessage(message);
    }
    recordedTrace.value = _recorder.build();
    _prompt.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? surfaceId = _turn == null ? null : '$_surfaceId-$_sessions';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_turn == null)
                _Hint(
                  onPick: _ask,
                  prompts: [
                    for (final turn in ScriptedAgent.turns) turn.prompt,
                  ],
                )
              else ...[
                for (final _Entry entry in _log) _EntryView(entry: entry),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Surface(
                      surfaceContext: _controller.contextFor(surfaceId!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prompt,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _ask,
                    decoration: InputDecoration(
                      hintText: 'Ask for something',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Send',
                        icon: const Icon(Icons.send),
                        onPressed: () => _ask(_prompt.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Start over',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _recorder.dispose();
                    _controller.dispose();
                    setState(() {
                      _log.clear();
                      _turn = null;
                      _sessions = 0;
                      _start();
                    });
                    recordedTrace.value = null;
                  },
                ),
              ],
            ),
          ),
        ),
        if (_turn != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Recorded so far: '
              '${recordedTrace.value?.steps.length ?? 0} steps. '
              'Open the Trace tab to step through them.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Who said what, for the little transcript above the surface.
class _Entry {
  const _Entry(this.who, this.text);

  factory _Entry.fromUser(String text) => _Entry('You', text);
  factory _Entry.fromAgent(String text) => _Entry('Agent', text);
  factory _Entry.fromApp(String text) => _Entry('Sent back', text);

  final String who;
  final String text;
}

class _EntryView extends StatelessWidget {
  const _EntryView({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = entry.who == 'You';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              entry.who,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.text,
              style: entry.who == 'Sent back'
                  ? theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.outline,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// What to ask, before anything has been asked.
class _Hint extends StatelessWidget {
  const _Hint({required this.prompts, required this.onPick});

  final List<String> prompts;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ask the agent for something', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'It answers with a surface built from this app\'s catalog, not with '
          'text. The agent is scripted so this runs offline; everything after '
          'it is the real thing.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String prompt in prompts)
              ActionChip(label: Text(prompt), onPressed: () => onPick(prompt)),
          ],
        ),
      ],
    );
  }
}
