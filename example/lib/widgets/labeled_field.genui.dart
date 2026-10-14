// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'labeled_field.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [GenUiComponent] for [LabeledField].
final GenUiComponent labeledFieldCatalogItem = GenUiComponent(
  name: 'LabeledField',
  schema: GenUiSchemas.component(
    description:
        'A labelled text input. Bind `value` to a data path and the '
        'field writes what the user types there. Attach `checks` and '
        'the message of the first failing rule is shown under the '
        'field.',
    properties: {
      'label': GenUiSchemas.string(description: 'The caption above the field.'),
      'value': GenUiSchemas.string(
        description:
            'What the field currently holds. The component writes the '
            'value the user chooses back to this property, so bind it to '
            'a data path if you need to read the result.',
      ),
      'checks': GenUiSchemas.checks(),
    },
    required: ['label', 'value'],
  ),
  examples: [
    r'''
[
  {
    "id": "root",
    "component": "LabeledField",
    "label": "Sample label",
    "value": {
      "path": "/value"
    }
  }
]''',
  ],
  builder: (context, node, props, buildChild) => LabeledField(
    label: props.string('label') ?? '',
    value: props.string('value') ?? '',
    onChanged: genUiWriter<String>(context, props, 'value'),
    error: props.validationErrors.firstOrNull,
  ),
);
