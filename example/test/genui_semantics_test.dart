// Records what every generated component exposes to assistive technology, and
// fails when that changes.
//
// The schema half of a catalog is checked when it is generated. This is the
// other half: what the model can actually make this app announce, press or
// report. It is also the part of a change nobody can see in a Dart diff, which
// is why `genui_semantics.json` is checked in and reviewed.
//
// Re-record after a deliberate change:
//
//   GENUI_UPDATE_GOLDENS=1 flutter test test/genui_semantics_test.dart

import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/testing.dart';

void main() {
  testWidgets('the catalog exposes what it exposed before', (tester) async {
    final recorded = <String, List<GenUiSemanticNode>>{};

    for (final item in exampleCatalog.items) {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiExampleSurface(catalog: exampleCatalog, item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      recorded[item.name] = genUiRenderedSemantics();
      handle.dispose();
    }

    expect(
      genUiSemanticsGolden(recorded, File('test/genui_semantics.json')),
      isNull,
    );
  });
}
