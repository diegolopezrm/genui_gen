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
  dataSchema: S.object(
    description:
        'A labelled text input. Bind `value` to a data path and the '
        'field writes what the user types there. Attach `checks` and '
        'the message of the first failing rule is shown under the '
        'field.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description: 'The caption above the field.',
      ),
      'value': A2uiSchemas.stringReference(
        description:
            'What the field currently holds. The component writes the '
            'value the user chooses back to this property, so bind it to '
            'a data path if you need to read the result.',
      ),
      'checks': A2uiSchemas.checkable(),
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'LabeledField', property);
      return fallback;
    }

    return GenUiChecks(
      dataContext: ctx.dataContext,
      checks: data['checks'],
      builder: (context, checked) => GenUiBindings(
        dataContext: ctx.dataContext,
        bindings: {
          'label': GenUiBinding.string(data['label']),
          'value': GenUiBinding.string(
            genUiWriteReference(ctx, data['value'], 'value'),
          ),
        },
        builder: (context, v) => LabeledField(
          label: v.string('label') ?? missing<String>('label', ''),
          value:
              (v.string('value') ?? genUiAsString(data['value'])) ??
              missing<String>('value', ''),
          onChanged: genUiValueWriter<String>(ctx, data['value'], 'value'),
          error: checked.message,
        ),
      ),
    );
  },
);
