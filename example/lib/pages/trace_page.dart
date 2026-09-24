import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui_gen/tracing.dart';

import '../main.dart';

/// The session that already happened, played back.
///
/// A generative interface has a problem an ordinary app does not: the screen
/// that failed is not in the source. This is the screen, kept — every message
/// the agent sent, the data model at each point, and every action the app sent
/// back — and it replays with no agent at all.
class TracePage extends StatefulWidget {
  const TracePage({super.key});

  @override
  State<TracePage> createState() => _TracePageState();
}

class _TracePageState extends State<TracePage> {
  GenUiTracePlayer? _player;
  GenUiTrace? _loaded;
  int _step = 0;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _load(GenUiTrace trace) {
    _player?.dispose();
    // Read back from text, the way a trace attached to a bug report arrives.
    final GenUiTrace reread = GenUiTrace.decode(trace.encode());
    _player = GenUiTracePlayer(reread, catalog: exampleCatalog)
      ..seek(reread.steps.length);
    _loaded = reread;
    _step = reread.steps.length;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ValueListenableBuilder<GenUiTrace?>(
      valueListenable: recordedTrace,
      builder: (context, trace, _) {
        if (trace == null || trace.steps.isEmpty) {
          return _Empty(theme: theme);
        }
        if (!identical(trace, _lastSeen)) {
          _lastSeen = trace;
          _load(trace);
        }

        final GenUiTrace current = _loaded!;
        final GenUiTracePlayer player = _player!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Step $_step of ${current.steps.length}',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              value: _step.toDouble(),
              max: current.steps.length.toDouble(),
              divisions: current.steps.length,
              label: '$_step',
              onChanged: (double value) {
                setState(() {
                  _step = value.round();
                  player.seek(_step);
                });
              },
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GenUiTraceView(player: player),
              ),
            ),
            const SizedBox(height: 16),
            Text('What happened', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < current.steps.length; i++)
              _StepTile(
                index: i,
                step: current.steps[i],
                selected: i == _step - 1,
                onTap: () => setState(() {
                  _step = i + 1;
                  player.seek(_step);
                }),
              ),
          ],
        );
      },
    );
  }

  GenUiTrace? _lastSeen;
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final GenUiTraceStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String kind, String summary) = switch (step) {
      GenUiMessageStep(:final message) => (
        'agent',
        message.keys.where((key) => key != 'version').join(', '),
      ),
      GenUiDataStep(:final surfaceId, :final data) => (
        'data',
        '$surfaceId  ${jsonEncode(data)}',
      ),
      GenUiEventStep(:final event) => ('app', jsonEncode(event)),
    };

    return Card(
      elevation: selected ? 2 : 0,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Chip(
          label: Text(kind),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        title: Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        trailing: Text(
          '${step.at.inMilliseconds} ms',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Nothing recorded yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ask the agent for something in the Session tab. Everything it '
              'sends, everything the data model holds and everything the app '
              'sends back is recorded here, and replays with no agent.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
