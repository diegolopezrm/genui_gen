import 'package:a2ui_core/a2ui_core.dart';
import 'package:example/main.dart';
import 'package:example/scripted_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';
import 'package:genui_gen/tracing.dart';

/// Records one session per scripted turn, the way a corpus of real sessions
/// would arrive: a directory of traces from bug reports or a canary run.
List<GenUiTrace> recordEveryTurn() {
  final traces = <GenUiTrace>[];
  for (var i = 0; i < ScriptedAgent.turns.length; i++) {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [exampleCatalog],
    );
    final recorder = GenUiTraceRecorder.attach(
      processor,
      catalogId: exampleCatalog.id,
    );
    for (final message in ScriptedAgent.turns[i].messages(
      'session-$i',
      exampleCatalog.id,
    )) {
      recorder.handleMessage(message);
    }
    traces.add(recorder.build());
    recorder.dispose();
    processor.dispose();
  }
  return traces;
}

void main() {
  test('what the agent actually used, and what the prompt paid for', () {
    final coverage = genUiCoverage(
      catalog: exampleCatalog,
      traces: recordEveryTurn(),
    );

    // ignore: avoid_print
    print(coverage.describe());

    expect(coverage.sessions, ScriptedAgent.turns.length);
    expect(coverage.componentUses.keys, contains('TaskList'));
    expect(coverage.componentShare, greaterThan(0));
  });

  test('a component nobody composes is named, with what it costs', () {
    final coverage = genUiCoverage(
      catalog: exampleCatalog,
      traces: recordEveryTurn(),
    );

    // ProductCard is in the catalog and the scripted agent never asks for it,
    // which is exactly the case this is for.
    expect(coverage.unusedComponents, contains('ProductCard'));
    expect(coverage.wastedCharacters, greaterThan(0));
  });

  test('an empty corpus says everything is unused rather than throwing', () {
    final coverage = genUiCoverage(
      catalog: exampleCatalog,
      traces: const <GenUiTrace>[],
    );
    expect(coverage.sessions, 0);
    expect(coverage.componentShare, 0);
    expect(coverage.unusedComponents.length, exampleCatalog.components.length);
  });
}
