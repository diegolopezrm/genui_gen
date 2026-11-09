// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'text_functions.dart';

// **************************************************************************
// GenUiFunctionGenerator
// **************************************************************************

/// Generated catalog function for [shortenName].
final FunctionImplementation shortenNameGenUiFunction = GenUiClientFunction(
  name: 'shortenName',
  description:
      'Shortens a full name for display. Use it when a surface has '
      'room for a name but not the whole one, such as a table cell '
      'or an avatar.',
  argumentSchema: S.object(
    properties: {
      'name': CommonSchemas.dynamicString,
      'style': S.combined(
        anyOf: [
          S.string(enumValues: ['initials', 'firstOnly', 'lastFirst']),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    },
    required: ['name'],
  ),
  returnType: A2uiReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return shortenName(
      genUiAsString(json['name']) ??
          genUiMissingField<String>(onMissing, 'name', ''),
      style:
          NameStyle.values.asNameMap()[genUiAsString(json['style'])] ??
          NameStyle.initials,
    );
  },
);

/// Generated catalog function for [formatPrice].
final FunctionImplementation formatPriceGenUiFunction = GenUiClientFunction(
  name: 'formatPrice',
  description:
      'Formats a number of cents as a price string, so the agent '
      'never has to do currency arithmetic itself.',
  argumentSchema: S.object(
    properties: {
      'cents': CommonSchemas.dynamicNumber,
      'currency': CommonSchemas.dynamicString,
    },
    required: ['cents'],
  ),
  returnType: A2uiReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return formatPrice(
      (genUiAsNum(json['cents']) ??
              genUiMissingField<num>(onMissing, 'cents', 0))
          .toInt(),
      currency: genUiAsString(json['currency']) ?? 'USD',
    );
  },
);

/// Generated catalog function for [describeMetric].
final FunctionImplementation describeMetricGenUiFunction = GenUiClientFunction(
  name: 'describeMetric',
  description:
      'Describes one metric in a sentence, for a tooltip or a '
      'summary line. Takes the same row object the tables take.',
  argumentSchema: S.object(
    properties: {
      'row': S.combined(
        anyOf: [
          metricRowGenUiSchema,
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    },
    required: ['row'],
  ),
  returnType: A2uiReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return describeMetric(switch (genUiAsObject(json['row'])) {
      final Map<String, Object?> nested => metricRowFromGenUiJson(
        nested,
        genUiNestedField(onMissing, 'row'),
      ),
      _ => genUiMissingField<MetricRow>(
        onMissing,
        'row',
        metricRowFromGenUiJson(const <String, Object?>{}),
      ),
    });
  },
);
