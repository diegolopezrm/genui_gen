// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'text_functions.dart';

// **************************************************************************
// GenUiFunctionGenerator
// **************************************************************************

/// Generated catalog function for [shortenName].
final ClientFunction shortenNameGenUiFunction = GenUiClientFunction(
  name: 'shortenName',
  description:
      'Shortens a full name for display. Use it when a surface has '
      'room for a name but not the whole one, such as a table cell '
      'or an avatar.',
  argumentSchema: S.object(
    properties: {
      'name': A2uiSchemas.stringReference(),
      'style': A2uiSchemas.stringReference(
        enumValues: ['initials', 'firstOnly', 'lastFirst'],
      ),
    },
    required: ['name'],
  ),
  returnType: ClientFunctionReturnType.string,
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
final ClientFunction formatPriceGenUiFunction = GenUiClientFunction(
  name: 'formatPrice',
  description:
      'Formats a number of cents as a price string, so the agent '
      'never has to do currency arithmetic itself.',
  argumentSchema: S.object(
    properties: {
      'cents': A2uiSchemas.numberReference(),
      'currency': A2uiSchemas.stringReference(),
    },
    required: ['cents'],
  ),
  returnType: ClientFunctionReturnType.string,
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
