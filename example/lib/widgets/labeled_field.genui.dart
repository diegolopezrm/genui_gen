// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'labeled_field.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [LabeledField].
final CatalogItem labeledFieldCatalogItem = CatalogItem(
  name: 'LabeledField',
  schema: S.object(
    description:
        'A labelled text input. Bind `value` to a data path and the '
        'field writes what the user types there. Attach `checks` and '
        'the message of the first failing rule is shown under the '
        'field.',
    properties: {
      'label': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'The caption above the field.',
      }),
      'value': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description':
            'What the field currently holds. The component writes the '
            'value the user chooses back to this property, so bind it to '
            'a data path if you need to read the result.',
      }),
      'checks': S.list(
        description: 'Validation rules for this component.',
        items: CommonSchemas.checkRule,
      ),
    },
    required: ['label', 'value'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "LabeledField",
    "label": "Sample label",
    "value": "Sample value"
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'LabeledField', property);
      return fallback;
    }

    final checked = GenUiCheckResult.of(props);
    return LabeledField(
      label:
          genUiAsString(props.value('label')) ?? missing<String>('label', ''),
      value:
          genUiAsString(genUiWrittenValue(node, props, 'value')) ??
          missing<String>('value', ''),
      onChanged: genUiValueWriter<String>(node, props, 'value'),
      error: checked.message,
    );
  },
);
