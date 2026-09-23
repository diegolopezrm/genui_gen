import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

/// The format version written into every trace.
///
/// A reader that meets a version it does not know refuses the file rather than
/// guessing: a trace is evidence about a session that cannot be reproduced any
/// other way, and half-reading one is worse than not reading it.
const int genUiTraceFormatVersion = 1;

/// One thing that happened during a recorded session.
sealed class GenUiTraceStep {
  const GenUiTraceStep(this.at);

  /// Reads back a step written by [toJson].
  factory GenUiTraceStep.fromJson(Map<String, Object?> json) {
    final Duration at = Duration(milliseconds: json['at']! as int);
    return switch (json['kind']) {
      'message' => GenUiMessageStep(
        at,
        (json['message']! as Map).cast<String, Object?>(),
      ),
      'data' => GenUiDataStep(at, json['surfaceId']! as String, json['data']),
      'event' => GenUiEventStep(at, json['event']),
      final Object? kind => throw FormatException('Unknown trace step: $kind'),
    };
  }

  /// How long after the start of the recording this happened.
  ///
  /// Kept because the gap between two steps is sometimes the bug: a surface
  /// that arrives in three updates half a second apart is a different user
  /// experience from one that arrives at once, and nothing else in the trace
  /// would say so.
  final Duration at;

  /// This step as JSON.
  Map<String, Object?> toJson();
}

/// A message the agent sent, exactly as it arrived.
final class GenUiMessageStep extends GenUiTraceStep {
  /// Creates a [GenUiMessageStep].
  const GenUiMessageStep(super.at, this.message);

  /// The raw message, in the shape `a2ui_core` reads and writes.
  final JsonMap message;

  /// The message, parsed.
  core.A2uiMessage decode() => core.A2uiMessage.fromJson(message);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.inMilliseconds,
    'kind': 'message',
    'message': message,
  };
}

/// The data model of one surface, as it stood after something changed it.
///
/// Recorded as a whole rather than as a diff. A surface's state is small, a
/// trace is read by a person, and a snapshot is the one form that cannot drift
/// from what was really there.
final class GenUiDataStep extends GenUiTraceStep {
  /// Creates a [GenUiDataStep].
  const GenUiDataStep(super.at, this.surfaceId, this.data);

  /// The surface the data belongs to.
  final String surfaceId;

  /// The contents of that surface's data model.
  final Object? data;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.inMilliseconds,
    'kind': 'data',
    'surfaceId': surfaceId,
    'data': data,
  };
}

/// Something the app sent back to the agent: an action the user took, or an
/// error the renderer reported.
///
/// Not replayed — it is an output, not an input — but it is half of the
/// question "what did the agent see before it answered that way".
final class GenUiEventStep extends GenUiTraceStep {
  /// Creates a [GenUiEventStep].
  const GenUiEventStep(super.at, this.event);

  /// The interaction payload, decoded.
  final Object? event;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.inMilliseconds,
    'kind': 'event',
    'event': event,
  };
}

/// A recorded session: everything the agent sent, everything the app sent
/// back, and the state in between.
///
/// A generative interface has a problem an ordinary app does not: the screen
/// that failed is not in the source. A model composed it, once, from a context
/// that will not come back. A trace is that screen, kept.
class GenUiTrace {
  /// Creates a [GenUiTrace].
  GenUiTrace({
    required this.steps,
    this.catalogId,
    DateTime? recordedAt,
    this.notes = const <String, Object?>{},
  }) : recordedAt = recordedAt ?? DateTime.now();

  /// Reads a trace back from [source].
  factory GenUiTrace.decode(String source) =>
      GenUiTrace.fromJson(jsonDecode(source) as Map<String, Object?>);

  /// Reads a trace back from its JSON.
  factory GenUiTrace.fromJson(Map<String, Object?> json) {
    final Object? version = json['version'];
    if (version != genUiTraceFormatVersion) {
      throw FormatException(
        'This trace is format $version; this version of genui_gen reads '
        'format $genUiTraceFormatVersion.',
      );
    }
    return GenUiTrace(
      catalogId: json['catalogId'] as String?,
      recordedAt: DateTime.parse(json['recordedAt']! as String),
      notes: (json['notes'] as Map?)?.cast<String, Object?>() ?? const {},
      steps: <GenUiTraceStep>[
        for (final step in json['steps']! as List<Object?>)
          GenUiTraceStep.fromJson((step! as Map).cast<String, Object?>()),
      ],
    );
  }

  /// What happened, in the order it happened.
  final List<GenUiTraceStep> steps;

  /// The catalog the session ran against.
  ///
  /// Replaying a trace against a different catalog is allowed and sometimes
  /// the point — that is how you find out whether today's catalog still
  /// renders yesterday's session — but the id is kept so the difference is
  /// visible rather than silent.
  final String? catalogId;

  /// When the recording started.
  final DateTime recordedAt;

  /// Anything the recorder was told to carry along: a build number, a user's
  /// bug report id, the model that answered.
  final Map<String, Object?> notes;

  /// The surfaces this session created, in order.
  List<String> get surfaceIds => <String>[
    for (final step in steps)
      if (step is GenUiMessageStep)
        if ((step.message['createSurface'] as Map?)?['surfaceId']
            case final String id)
          id,
  ];

  /// This trace as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': genUiTraceFormatVersion,
    'recordedAt': recordedAt.toIso8601String(),
    if (catalogId != null) 'catalogId': catalogId,
    if (notes.isNotEmpty) 'notes': notes,
    'steps': <Object?>[for (final step in steps) step.toJson()],
  };

  /// This trace as indented JSON, for a file that is read in review.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}
