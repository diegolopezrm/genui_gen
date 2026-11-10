import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

import 'trace.dart';

/// Records a session so it can be replayed later.
///
/// Attach it to the app's [MessageProcessor] and send the agent's messages
/// through it instead of straight to the processor:
///
/// ```dart
/// final recorder = GenUiTraceRecorder.attach(
///   processor,
///   catalogId: catalog.id,
///   redact: const ['/user/email'],
/// );
///
/// transport.messages.listen(recorder.processMessages);
/// ...
/// await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
/// ```
///
/// What it keeps: every message the agent sent, the contents of each surface's
/// data model whenever they changed, and every action or error the app sent
/// back. That is everything the renderer saw, which is what makes the replay
/// faithful rather than approximate.
///
/// What it cannot keep: anything a component reads from outside the data
/// model. A component that asks the clock or the network for something renders
/// from that, not from the trace, and replays differently. Keep those behind a
/// function the catalog declares, and the trace covers them too.
class GenUiTraceRecorder {
  /// Creates a recorder attached to [processor].
  ///
  /// [redact] lists JSON Pointer paths whose values never reach the file.
  /// Recording a session records what the user typed, so a field holding an
  /// email or a card number has to be named here before the first recording,
  /// not after the first leak.
  GenUiTraceRecorder.attach(
    this.processor, {
    this.catalogId,
    List<String> redact = const <String>[],
    Map<String, Object?> notes = const <String, Object?>{},
  }) : _redact = redact.map(_segmentsOf).toList(),
       _notes = notes {
    final SurfaceGroupModel<ComponentImplementation> group = processor.model;
    _subscriptions
      ..add(group.onAction.subscribe(_recordAction))
      ..add(group.onSurfaceCreated.subscribe(_watch))
      ..add(group.onSurfaceDeleted.subscribe(_forget));
    group.allSurfaces.forEach(_watch);
  }

  /// The processor the messages are handed to.
  final MessageProcessor<ComponentImplementation> processor;

  /// The catalog the session runs against, written into the trace.
  final String? catalogId;

  final List<List<String>> _redact;
  final Map<String, Object?> _notes;
  final List<GenUiTraceStep> _steps = <GenUiTraceStep>[];
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, _Watched> _watched = <String, _Watched>{};
  final List<Subscription> _subscriptions = <Subscription>[];
  final _Changes _changes = _Changes();

  /// Fires whenever a step is recorded.
  ///
  /// A trace is a growing list and [build] takes a snapshot of it, so anything
  /// showing the session as it happens needs to know when to take another one.
  Listenable get changes => _changes;

  /// Records [payload] and hands it to the processor.
  ///
  /// [payload] is whatever [MessageProcessor.processMessages] takes: decoded
  /// JSON, a parsed message or a list of either. Each message is recorded
  /// before it is processed, so a message the processor rejects is in the
  /// trace too, as what the agent sent; the rejection is thrown as it would
  /// have been.
  void processMessages(Object? payload) {
    for (final Map<String, Object?> json in _messagesOf(payload)) {
      // A copy, taken now: the data model can adopt an updateDataModel's
      // value and write into it as the person types, at which point the
      // message is no longer what the agent sent.
      _steps.add(
        GenUiMessageStep(
          _clock.elapsed,
          _redactedMessage(_copy(json)! as Map<String, Object?>),
        ),
      );
    }
    _changes.notify();
    processor.processMessages(payload);
  }

  /// The trace so far.
  GenUiTrace build() => GenUiTrace(
    steps: List<GenUiTraceStep>.unmodifiable(_steps),
    catalogId: catalogId,
    notes: _notes,
  );

  /// Stops recording and releases what the recorder listens to.
  void dispose() {
    for (final Subscription subscription in _subscriptions) {
      subscription.unsubscribe();
    }
    _subscriptions.clear();
    for (final _Watched watched in _watched.values) {
      watched.cancel();
    }
    _watched.clear();
    _clock.stop();
    _changes.dispose();
  }

  void _watch(SurfaceModel<ComponentImplementation> surface) {
    if (_watched.containsKey(surface.id)) return;
    final ReadonlySignal<Object?> root = surface.dataModel.watch<Object?>('/');
    var first = true;
    final void Function() unsubscribe = root.subscribe((Object? data) {
      // A surface may already hold data when it is first watched:
      // `updateDataModel` can arrive in the same batch as `createSurface`.
      // An empty model is not worth a step.
      final bool empty = data == null || (data is Map && data.isEmpty);
      if (first && empty) {
        first = false;
        return;
      }
      first = false;
      _steps.add(GenUiDataStep(_clock.elapsed, surface.id, _snapshot(data)));
      _changes.notify();
    });
    void onError(A2uiRendererError error) => _recordEvent(
      ErrorMessage(version: _versionOf(surface), error: error).toJson(),
    );
    final Subscription errors = surface.onError.subscribe(onError);
    _watched[surface.id] = _Watched(root, () {
      unsubscribe();
      errors.unsubscribe();
    });
  }

  void _forget(String surfaceId) => _watched.remove(surfaceId)?.cancel();

  void _recordAction(A2uiRendererAction action) => _recordEvent(
    ActionMessage(
      version: _versionOf(processor.model.getSurface(action.surfaceId)),
      action: action,
    ).toJson(),
  );

  /// The version an event from [surface] goes back to the agent in: the one
  /// the surface was created with.
  static String _versionOf(SurfaceModel<ComponentImplementation>? surface) =>
      surface?.protocolVersion ?? A2uiProtocolVersion.v0_9.jsonValue;

  void _recordEvent(Map<String, Object?> message) {
    _steps.add(GenUiEventStep(_clock.elapsed, _redacted(_copy(message))));
    _changes.notify();
  }

  /// [value], copied so later writes to the data model cannot change it, and
  /// with the redacted paths blanked.
  Object? _snapshot(Object? value) => _redacted(_copy(value));

  /// The decoded JSON of each message in [payload].
  static Iterable<Map<String, Object?>> _messagesOf(Object? payload) sync* {
    switch (payload) {
      case AgentToRendererMessagePayload(:final messages):
        for (final AgentToRendererMessage message in messages) {
          yield message.toJson();
        }
      case final AgentToRendererMessage message:
        yield message.toJson();
      case final List<Object?> list:
        for (final Object? item in list) {
          yield* _messagesOf(item);
        }
      case final Map<Object?, Object?> map when map.containsKey('messages'):
        yield* _messagesOf(map['messages']);
      case final Map<Object?, Object?> map:
        yield map.cast<String, Object?>();
    }
  }

  Map<String, Object?> _redactedMessage(Map<String, Object?> json) {
    if (_redact.isEmpty) return json;
    final Object? update = json['updateDataModel'];
    if (update is! Map<String, Object?>) return json;
    final List<String> at = _segmentsOf(update['path'] as String? ?? '');
    for (final path in _redact) {
      if (_startsWith(at, path)) {
        // The message writes somewhere inside a redacted path.
        update['value'] = '[redacted]';
      } else if (_startsWith(path, at)) {
        // The redacted path is inside the value the message writes.
        _blank(update['value'], path.sublist(at.length));
      }
    }
    return json;
  }

  static bool _startsWith(List<String> path, List<String> prefix) {
    if (prefix.length > path.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  /// [value] with every redacted path replaced.
  /// [value], already a copy, with the redacted paths blanked.
  Object? _redacted(Object? value) {
    for (final path in _redact) {
      _blank(value, path);
    }
    return value;
  }

  static Object? _copy(Object? value) => switch (value) {
    final Map<Object?, Object?> map => <String, Object?>{
      for (final entry in map.entries) '${entry.key}': _copy(entry.value),
    },
    final List<Object?> list => <Object?>[for (final item in list) _copy(item)],
    _ => value,
  };

  static void _blank(Object? node, List<String> path) {
    Object? current = node;
    for (var i = 0; i < path.length - 1; i++) {
      current = _child(current, path[i]);
      if (current == null) return;
    }
    final String last = path.last;
    if (current is Map<String, Object?> && current.containsKey(last)) {
      current[last] = '[redacted]';
    } else if (current is List<Object?>) {
      final int? index = int.tryParse(last);
      if (index != null && index >= 0 && index < current.length) {
        current[index] = '[redacted]';
      }
    }
  }

  static Object? _child(Object? node, String segment) {
    if (node is Map<String, Object?>) return node[segment];
    if (node is List<Object?>) {
      final int? index = int.tryParse(segment);
      if (index != null && index >= 0 && index < node.length) {
        return node[index];
      }
    }
    return null;
  }

  static List<String> _segmentsOf(String path) =>
      path.split('/').where((String segment) => segment.isNotEmpty).toList();
}

/// A notifier the recorder can fire.
///
/// `notifyListeners` is protected, and a recorder is not itself a notifier:
/// nothing rebuilds from the recorder, only from [GenUiTraceRecorder.changes].
class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// A watched surface: its data model's root signal, held so the data model's
/// weak reference to it stays alive, and how to stop watching.
class _Watched {
  _Watched(this.root, this.cancel);

  final ReadonlySignal<Object?> root;
  final void Function() cancel;
}
