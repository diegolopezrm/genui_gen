import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';

void main() {
  testWidgets(
    'every generated component survives what its schema allows',
    (tester) async {
      final findings = await genUiFuzz(
        catalog: exampleCatalog,
        pump: tester.pumpWidget,
      );

      expect(
        findings,
        isEmpty,
        reason:
            '${genUiFuzzSummary(findings)}\n\n'
            '${findings.take(10).join('\n\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
