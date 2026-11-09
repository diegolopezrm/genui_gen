// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'preference_row.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [PreferenceRow].
final CatalogItem preferenceRowCatalogItem = CatalogItem(
  name: 'PreferenceRow',
  schema: S.object(
    description:
        'One preference the user can turn on or off, with a label and '
        'an optional line of explanation. Use it when you need the '
        'user to answer yes or no and you want to read the answer '
        'back: bind `enabled` to a data path, and the switch writes '
        'the new state there.',
    properties: {
      'label': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description':
            'A short caption naming the preference, e.g. "Weekly '
            'summary".',
      }),
      'enabled': S.fromMap({
        ...CommonSchemas.dynamicBoolean.value,
        'description':
            'Whether the preference is currently on. The component writes '
            'the value the user chooses back to this property, so bind it '
            'to a data path if you need to read the result.',
      }),
      'detail': S.fromMap({
        ...CommonSchemas.dynamicString.value,
        'description': 'One line of explanation shown under the label.',
      }),
    },
    required: ['label', 'enabled'],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "PreferenceRow",
    "label": "Sample label",
    "enabled": true
  }
]''',
  ],
  builder: (context, node, props, buildChild) {
    T missing<T>(String property, T fallback) {
      genUiReportMissing(node, 'PreferenceRow', property);
      return fallback;
    }

    return PreferenceRow(
      label:
          genUiAsString(props.value('label')) ?? missing<String>('label', ''),
      enabled:
          genUiAsBool(genUiWrittenValue(node, props, 'enabled')) ??
          missing<bool>('enabled', false),
      detail: genUiAsString(props.value('detail')),
      onChanged: genUiValueWriter<bool>(node, props, 'enabled'),
    );
  },
);
