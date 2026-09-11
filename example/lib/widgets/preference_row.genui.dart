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
  dataSchema: S.object(
    description:
        'One preference the user can turn on or off, with a label and '
        'an optional line of explanation. Use it when you need the '
        'user to answer yes or no and you want to read the answer '
        'back: bind `enabled` to a data path, and the switch writes '
        'the new state there.',
    properties: {
      'label': A2uiSchemas.stringReference(
        description:
            'A short caption naming the preference, e.g. "Weekly '
            'summary".',
      ),
      'enabled': A2uiSchemas.booleanReference(
        description:
            'Whether the preference is currently on. The component writes '
            'the value the user chooses back to this property, so bind it '
            'to a data path if you need to read the result.',
      ),
      'detail': A2uiSchemas.stringReference(
        description: 'One line of explanation shown under the label.',
      ),
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
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'PreferenceRow', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'label': GenUiBinding.string(data['label']),
        'enabled': GenUiBinding.bool(
          genUiWriteReference(ctx, data['enabled'], 'enabled'),
        ),
        'detail': GenUiBinding.string(data['detail']),
      },
      builder: (context, v) => PreferenceRow(
        label: v.string('label') ?? missing<String>('label', ''),
        enabled:
            (v.boolean('enabled') ?? genUiAsBool(data['enabled'])) ??
            missing<bool>('enabled', false),
        detail: v.string('detail'),
        onChanged: genUiValueWriter<bool>(ctx, data['enabled'], 'enabled'),
      ),
    );
  },
);
