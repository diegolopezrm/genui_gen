import 'package:genui_gen/genui_gen.dart';

part 'text_functions.genui.dart';

/// How a name should be shortened.
enum NameStyle { initials, firstOnly, lastFirst }

@GenUiFunction(
  description:
      'Shortens a full name for display. Use it when a surface has room for '
      'a name but not the whole one, such as a table cell or an avatar.',
)
String shortenName(String name, {NameStyle style = NameStyle.initials}) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return switch (style) {
    NameStyle.initials => parts.map((p) => p[0].toUpperCase()).join(),
    NameStyle.firstOnly => parts.first,
    NameStyle.lastFirst => parts.length == 1
        ? parts.first
        : '${parts.last}, ${parts.first}',
  };
}

@GenUiFunction(
  description:
      'Formats a number of cents as a price string, so the agent never has to '
      'do currency arithmetic itself.',
)
String formatPrice(int cents, {String currency = 'USD'}) {
  final whole = (cents ~/ 100).toString();
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$currency $whole.$fraction';
}
