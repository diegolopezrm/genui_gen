import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:genui_gen/testing.dart';
import 'package:genui_gen/tracing.dart';

CatalogItem item(String name, Map<String, Schema> properties) => CatalogItem(
  name: name,
  schema: S.object(description: name, properties: properties),
  exampleData: [() => '[{"id": "root", "component": "$name"}]'],
  builder: (context, node, props, buildChild) => const SizedBox(),
);

final CatalogImplementation catalog = CatalogImplementation(
  id: 'test.coverage',
  components: [
    item('Used', {
      'title': CommonSchemas.dynamicString,
      'never': CommonSchemas.dynamicString,
      // The shape the generator gives an enum property.
      'tone': S.combined(
        anyOf: [
          S.string(enumValues: ['warm', 'cold', 'grey']),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    }),
    item('Unused', {'title': CommonSchemas.dynamicString}),
  ],
);

/// A trace holding one surface composed of [components].
GenUiTrace traceOf(List<Map<String, Object?>> components) {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [catalog],
    reportErrorsOnly: true,
  );
  final recorder = GenUiTraceRecorder.attach(processor, catalogId: catalog.id);
  final String version = A2uiProtocolVersion.v0_9.jsonValue;
  recorder
    ..handleMessage(
      CreateSurfaceMessage(
        version: version,
        surfaceId: 's',
        catalogId: catalog.id,
      ),
    )
    ..handleMessage(
      UpdateComponentsMessage(
        version: version,
        surfaceId: 's',
        components: components,
      ),
    );
  final trace = recorder.build();
  recorder.dispose();
  processor.dispose();
  return trace;
}

void main() {
  test('counts what the agent composed and names what it never did', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: [
        traceOf([
          {'id': 'root', 'component': 'Used', 'title': 'hello', 'tone': 'warm'},
        ]),
      ],
    );

    expect(coverage.sessions, 1);
    expect(coverage.surfaces, 1);
    expect(coverage.componentUses, {'Used': 1});
    expect(coverage.unusedComponents, {'Unused'});
    expect(coverage.componentShare, 0.5);
  });

  test('a property the agent never filled is named, per component', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: [
        traceOf([
          {'id': 'root', 'component': 'Used', 'title': 'hello'},
        ]),
      ],
    );

    expect(coverage.unusedProperties['Used'], contains('never'));
    expect(coverage.unusedProperties['Used'], isNot(contains('title')));
    // A component nobody composed is reported whole, not property by
    // property, which would say the same thing many times over.
    expect(coverage.unusedProperties.containsKey('Unused'), isFalse);
  });

  test('an enum value the agent never chose is named', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: [
        traceOf([
          {'id': 'root', 'component': 'Used', 'tone': 'warm'},
        ]),
      ],
    );

    expect(coverage.unusedEnumValues['Used.tone'], {'cold', 'grey'});
  });

  test('two sessions add up rather than overwrite', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: [
        traceOf([
          {'id': 'root', 'component': 'Used', 'title': 'a'},
        ]),
        traceOf([
          {'id': 'root', 'component': 'Used', 'never': 'b'},
        ]),
      ],
    );

    expect(coverage.sessions, 2);
    expect(coverage.componentUses['Used'], 2);
    // title and never were each filled in one of the two sessions, so the
    // corpus as a whole covers both. tone was filled in neither.
    expect(coverage.unusedProperties['Used'], {'tone'});
  });

  test('it says what the unused part costs the prompt', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: [
        traceOf([
          {'id': 'root', 'component': 'Used'},
        ]),
      ],
    );

    expect(coverage.weight, isNotNull);
    expect(coverage.wastedCharacters, greaterThan(0));
    expect(coverage.describe(), contains('never composed'));
    expect(coverage.describe(), contains('Unused'));
  });

  test('no traces at all is every component unused, not a crash', () {
    final coverage = genUiCoverage(
      catalog: catalog,
      traces: const <GenUiTrace>[],
    );
    expect(coverage.sessions, 0);
    expect(coverage.componentShare, 0);
    expect(coverage.unusedComponents, {'Used', 'Unused'});
  });
}
