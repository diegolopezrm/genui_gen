import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

import 'trace.dart';

/// Replays a recorded session, without a model and without a network.
///
/// A trace is data, so a replay is deterministic: the same messages in the
/// same order produce the same surfaces. That is what makes a bug report
/// reproducible — and what makes a session from last week a regression test
/// today.
///
/// ```dart
/// final player = GenUiTracePlayer(trace, catalog: genUiCatalog);
/// player.seek(7);                       // the step the user complained about
/// await tester.pumpWidget(
///   MaterialApp(home: GenUiTraceView(player: player)),
/// );
/// ```
class GenUiTracePlayer {
  /// Creates a player for [trace].
  ///
  /// [catalog] is usually the app's current catalog, which is the point:
  /// replaying an old session against today's components is how you find out
  /// that a component the agent still asks for no longer exists.
  GenUiTracePlayer(this.trace, {required this.catalog}) {
    _controller = SurfaceController(catalogs: [catalog]);
  }

  /// The session being replayed.
  final GenUiTrace trace;

  /// The catalog the replay renders with.
  final Catalog catalog;

  late SurfaceController _controller;
  int _position = 0;

  /// The controller holding the replayed surfaces.
  SurfaceController get controller => _controller;

  /// How many steps the trace holds.
  int get length => trace.steps.length;

  /// How many steps have been applied.
  int get position => _position;

  /// The surface the replay is showing, which is the last one created up to
  /// [position].
  String? get currentSurfaceId {
    String? id;
    for (final step in trace.steps.take(_position)) {
      if (step is GenUiMessageStep) {
        if ((step.message['createSurface'] as Map?)?['surfaceId']
            case final String created) {
          id = created;
        }
      }
    }
    return id;
  }

  /// Applies the first [step] steps, from the beginning.
  ///
  /// Rebuilt from scratch rather than stepped backwards: a surface has no undo,
  /// and a replay that rewound by guessing would be a different session from
  /// the one recorded.
  void seek(int step) {
    final int target = step.clamp(0, length);
    if (target < _position) {
      _controller.dispose();
      _controller = SurfaceController(catalogs: [catalog]);
      _position = 0;
    }
    for (var i = _position; i < target; i++) {
      _apply(trace.steps[i]);
    }
    _position = target;
  }

  /// Applies every remaining step.
  void seekToEnd() => seek(length);

  /// Applies the next step, if there is one.
  void step() => seek(_position + 1);

  void _apply(GenUiTraceStep step) {
    switch (step) {
      case GenUiMessageStep():
        _controller.handleMessage(step.decode());
      case GenUiDataStep():
        // Written whole, at the root, because that is how it was recorded: the
        // state of a surface at a moment, not the difference from the one
        // before it.
        _controller
            .contextFor(step.surfaceId)
            .dataModel
            .update(DataPath(''), step.data);
      case GenUiEventStep():
        // What the app told the agent is not an input to the replay. It is
        // kept in the trace because it explains what the agent answered next.
        break;
    }
  }

  /// Releases the replayed surfaces.
  void dispose() => _controller.dispose();
}

/// Shows the surface a [GenUiTracePlayer] is currently holding.
///
/// Built for a debug screen and for tests: a bug report becomes a widget you
/// can step through.
class GenUiTraceView extends StatelessWidget {
  /// Creates a [GenUiTraceView].
  const GenUiTraceView({super.key, required this.player, this.surfaceId});

  /// The player to show.
  final GenUiTracePlayer player;

  /// Which surface to show; the most recently created one by default.
  final String? surfaceId;

  @override
  Widget build(BuildContext context) {
    final String? id = surfaceId ?? player.currentSurfaceId;
    if (id == null) return const SizedBox.shrink();
    return Surface(surfaceContext: player.controller.contextFor(id));
  }
}
