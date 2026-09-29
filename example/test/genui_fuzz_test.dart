import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';

/// Components of genui's basic catalog that crash on input their own schema
/// permits, reported as a2ui-project/a2ui#2872.
///
/// They are named here rather than left out of the run, so the day they are
/// fixed this list is what tells us.
const upstreamCrashes = <String>{
  'Slider',
  'Tabs',
  'TextField',
  'DateTimeInput',
  'Row',
};

void main() {
  testWidgets('every generated component survives what its schema allows', (
    tester,
  ) async {
    final findings = await genUiFuzz(
      catalog: exampleCatalog,
      pump: tester.pumpWidget,
      skip: upstreamCrashes,
    );

    expect(
      findings,
      isEmpty,
      reason: '${genUiFuzzSummary(findings)}\n\n'
          '${findings.take(10).join('\n\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('the upstream ones still crash, so we know when they stop', (
    tester,
  ) async {
    final findings = await genUiFuzz(
      catalog: exampleCatalog,
      pump: tester.pumpWidget,
      only: upstreamCrashes,
    );

    // Not an assertion that they should crash. It is a reminder to delete the
    // skip list when they no longer do.
    if (findings.isEmpty) {
      // ignore: avoid_print
      print(
        'a2ui#2872 looks fixed upstream: nothing in $upstreamCrashes threw. '
        'Remove them from upstreamCrashes.',
      );
    } else {
      // ignore: avoid_print
      print('still broken upstream (a2ui#2872):\n${genUiFuzzSummary(findings)}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
