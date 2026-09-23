import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'trace.dart';

/// Records a session so it can be replayed later.
///
/// Attach it to the controller and send the agent's messages through it
/// instead of straight to the controller:
///
/// ```dart
/// final recorder = GenUiTraceRecorder.attach(
///   controller,
///   catalogId: catalog.catalogId,
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
  /// Creates a recorder attached to [controller].
  ///
  /// [redact] lists JSON Pointer paths whose values never reach the file.
  /// Recording a session records what the user typed, so a field holding an
  /// email or a card number has to be named here before the first recording,
  /// not after the first leak.
  GenUiTraceRecorder.attach(
    this.controller, {
    this.catalogId,
    List<String> redact = const <String>[],
    Map<String, Object?> notes = const <String, Object?>{},
  }) : _redact = redact.map(_segmentsOf).toList(),
       _notes = notes {
    _submissions = controller.onSubmit.listen(_recordSubmission);
  }

  /// The controller messages are forwarded to.
  final SurfaceController controller;

  /// The catalog the session runs against, written into the trace.
  final String? catalogId;

  final List<List<String>> _redact;
  final Map<String, Object?> _notes;
  final List<GenUiTraceStep> _steps = <GenUiTraceStep>[];
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, VoidCallback> _dataListeners = <String, VoidCallback>{};

  late final StreamSubscription<ChatMessage> _submissions;

  /// Records [message] and hands it to the controller.
  void handleMessage(core.A2uiMessage message) {
    final JsonMap json = message.toJson();
    _steps.add(GenUiMessageStep(_clock.elapsed, json));
    controller.handleMessage(message);

    // A surface can only be watched once it exists, which is after the
    // controller has handled the message that creates it.
    if ((json['createSurface'] as Map?)?['surfaceId'] case final String id) {
      _watchData(id);
    }
  }

  /// The session so far.
  GenUiTrace build() => GenUiTrace(
    steps: List<GenUiTraceStep>.unmodifiable(_steps),
    catalogId: catalogId,
    notes: _notes,
  );

  /// Stops recording and releases what it was listening to.
  ///
  /// The controller is left alone: the recorder was given it, not created by
  /// it.
  void dispose() {
    _submissions.cancel();
    for (final entry in _dataListeners.entries) {
      _rootOf(entry.key).removeListener(entry.value);
    }
    _dataListeners.clear();
    _clock.stop();
  }

  ValueListenable<Object?> _rootOf(String surfaceId) => controller
      .contextFor(surfaceId)
      .dataModel
      .subscribe<Object?>(DataPath(''));

  void _watchData(String surfaceId) {
    if (_dataListeners.containsKey(surfaceId)) return;
    final ValueListenable<Object?> root = _rootOf(surfaceId);
    void listener() {
      _steps.add(
        GenUiDataStep(_clock.elapsed, surfaceId, _redacted(root.value)),
      );
    }

    root.addListener(listener);
    _dataListeners[surfaceId] = listener;
    // The surface may already hold data: `updateDataModel` can arrive in the
    // same batch as `createSurface`, before there was anything to listen with.
    if (root.value != null) listener();
  }

  void _recordSubmission(ChatMessage message) {
    for (final part in message.parts) {
      if (part is! DataPart) continue;
      if (part.mimeType != UiPartConstants.interactionMimeType) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(part.bytes));
      } on FormatException {
        // A part that is not the JSON it claims to be is worth keeping as the
        // text it was: it is evidence about a bug, not a value to parse.
        decoded = utf8.decode(part.bytes, allowMalformed: true);
      }
      _steps.add(GenUiEventStep(_clock.elapsed, _redacted(decoded)));
    }
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
