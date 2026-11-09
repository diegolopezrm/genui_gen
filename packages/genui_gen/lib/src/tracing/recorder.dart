import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';

import 'trace.dart';

/// Records a session so it can be replayed later.
///
/// Attach it to the processor and send the agent's messages through it
/// instead of straight to the processor:
///
/// ```dart
/// final recorder = GenUiTraceRecorder.attach(
///   processor,
///   catalogId: catalog.id,
///   redact: const ['/user/email'],
/// );
///
/// transport.messages.listen(recorder.handleMessage);
/// ...
/// await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
/// ```
///
/// What it keeps: every message the agent sent, the contents of each surface's
/// data model whenever they changed, and every action or error the app sent
/// back. That is everything the renderer saw, which is what makes the replay
/// faithful rather than approximate.
///
/// What it cannot keep: anything a catalog item reads from outside the data
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
    _subscriptions
      ..add(processor.model.onSurfaceCreated.subscribe(_watchData))
      ..add(processor.model.onSurfaceDeleted.subscribe(_unwatchData))
      ..add(processor.model.onAction.subscribe(_recordAction))
      ..add(processor.model.onError.subscribe(_recordError));
  }

  /// The processor messages are forwarded to.
  final MessageProcessor<ComponentImplementation> processor;

  /// The catalog the session runs against, written into the trace.
  final String? catalogId;

  final List<List<String>> _redact;
  final Map<String, Object?> _notes;
  final List<GenUiTraceStep> _steps = <GenUiTraceStep>[];
  final Stopwatch _clock = Stopwatch()..start();
  final List<Subscription> _subscriptions = <Subscription>[];
  final Map<String, DataSubscription<Object?>> _dataSubscriptions =
      <String, DataSubscription<Object?>>{};
  final _Changes _changes = _Changes();

  /// Fires whenever a step is recorded.
  ///
  /// A trace is a growing list and [build] takes a snapshot of it, so anything
  /// showing the session as it happens needs to know when to take another one.
  Listenable get changes => _changes;

  /// Records [message] and hands it to the processor.
  void handleMessage(AgentToRendererMessage message) {
    final Map<String, Object?> json = message.toJson();
    // A copy, taken now. The data model can adopt an updateDataModel's value
    // and write into it as the person types, at which point the message is no
    // longer what the agent sent. Recording it by reference would record the
    // person's input as the agent's, and past [redact].
    _steps.add(
      GenUiMessageStep(
        _clock.elapsed,
        _redactedMessage(_copy(json)! as Map<String, Object?>),
      ),
    );
    _changes.notify();
    processor.processMessages(json);
  }

  /// The session so far.
  GenUiTrace build() => GenUiTrace(
    steps: List<GenUiTraceStep>.unmodifiable(_steps),
    catalogId: catalogId,
    notes: _notes,
  );

  /// Stops recording and releases what it was listening to.
  ///
  /// The processor is left alone: the recorder was given it, not created by
  /// it.
  void dispose() {
    for (final Subscription subscription in _subscriptions) {
      subscription.unsubscribe();
    }
    _subscriptions.clear();
    for (final DataSubscription<Object?> data in _dataSubscriptions.values) {
      data.unsubscribe();
    }
    _dataSubscriptions.clear();
    _clock.stop();
    _changes.dispose();
  }

  void _watchData(SurfaceModel<ComponentImplementation> surface) {
    final String surfaceId = surface.id;
    if (_dataSubscriptions.containsKey(surfaceId)) return;
    void record(Object? value) {
      _steps.add(GenUiDataStep(_clock.elapsed, surfaceId, _redacted(value)));
      _changes.notify();
    }

    final DataSubscription<Object?> data = surface.dataModel.subscribe<Object?>(
      '/',
      record,
    );
    _dataSubscriptions[surfaceId] = data;
    // The surface may already hold data, written before there was anything to
    // listen with.
    final Object? current = data.value;
    if (current != null) record(current);
  }

  void _unwatchData(String surfaceId) {
    _dataSubscriptions.remove(surfaceId)?.unsubscribe();
  }

  void _recordAction(A2uiRendererAction action) {
    _recordEvent(
      ActionMessage(version: _versionOf(action.surfaceId), action: action),
    );
  }

  void _recordError(A2uiRendererError error) {
    _recordEvent(
      ErrorMessage(version: _versionOf(error.surfaceId), error: error),
    );
  }

  void _recordEvent(RendererToAgentMessage message) {
    _steps.add(GenUiEventStep(_clock.elapsed, _redacted(message.toJson())));
    _changes.notify();
  }

  /// The protocol version the surface speaks, which is the version the app
  /// answers it in.
  String _versionOf(String? surfaceId) =>
      processor.model.getSurface(surfaceId ?? '')?.protocolVersion ??
      A2uiProtocolVersion.v0_9.jsonValue;

  /// [json] with every redacted path blanked in what an updateDataModel
  /// writes.
  ///
  /// An agent can put personal data in the data model as easily as the
  /// person can, from a tool that looked up their email for instance, and a
  /// path named in [redact] never reaches the file whoever wrote it.
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
  Object? _redacted(Object? value) {
    if (_redact.isEmpty) return value;
    final Object? copy = _copy(value);
    for (final path in _redact) {
      _blank(copy, path);
    }
    return copy;
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
