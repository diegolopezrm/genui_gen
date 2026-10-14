// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'preference_row.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [GenUiComponent] for [PreferenceRow].
final GenUiComponent preferenceRowCatalogItem = GenUiComponent(
  name: 'PreferenceRow',
  schema: GenUiSchemas.component(
    description:
        'One preference the user can turn on or off, with a label and '
        'an optional line of explanation. Use it when you need the '
        'user to answer yes or no and you want to read the answer '
        'back: bind `enabled` to a data path, and the switch writes '
        'the new state there.',
    properties: {
      'label': GenUiSchemas.string(
        description:
            'A short caption naming the preference, e.g. "Weekly '
            'summary".',
      ),
      'enabled': GenUiSchemas.boolean(
        description:
            'Whether the preference is currently on. The component writes '
            'the value the user chooses back to this property, so bind it '
            'to a data path if you need to read the result.',
      ),
      'detail': GenUiSchemas.string(
        description: 'One line of explanation shown under the label.',
      ),
    },
    required: ['label', 'enabled'],
  ),
  examples: [
    r'''
[
  {
    "id": "root",
    "component": "PreferenceRow",
    "label": "Sample label",
    "enabled": true
  }
]''',
  ],
  builder: (context, node, props, buildChild) => PreferenceRow(
    label: props.string('label') ?? '',
    enabled: props.boolean('enabled') ?? false,
    detail: props.string('detail'),
    onChanged: genUiWriter<bool>(context, props, 'enabled'),
  ),
);
