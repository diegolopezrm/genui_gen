/// Small string helpers shared by the analysis and emission steps.
library;

/// Renders [value] as a single-quoted Dart string literal.
String dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return "'$escaped'";
}

/// Renders [value] as one or more adjacent single-quoted Dart string
/// literals, each at most [width] characters of content, split on spaces.
///
/// Long descriptions would otherwise produce lines well past 80 columns in
/// generated files, since `dart format` never splits a string literal.
/// Adjacent literals are placed on separate lines and re-indented by the
/// formatter.
String dartWrappedString(String value, {int width = 60}) {
  if (value.length <= width) return dartString(value);
  final chunks = <String>[];
  final buffer = StringBuffer();
  for (final word in value.split(' ')) {
    final candidate = buffer.isEmpty ? word : '$buffer $word';
    if (buffer.isNotEmpty && candidate.length > width) {
      chunks.add('$buffer ');
      buffer
        ..clear()
        ..write(word);
    } else {
      buffer
        ..clear()
        ..write(candidate);
    }
  }
  if (buffer.isNotEmpty) chunks.add(buffer.toString());
  return chunks.map(dartString).join('\n');
}

/// Renders a nullable [value] as a Dart expression (`null` or a literal).
String dartStringOrNull(String? value) =>
    value == null ? 'null' : dartString(value);

/// Turns a raw documentation comment into a single-line description.
///
/// Strips `///` / `/** */` markers, removes `{@template}`-style macros,
/// collapses whitespace and joins lines with single spaces. Returns `null`
/// when nothing meaningful is left.
String? cleanDocComment(String? raw) {
  if (raw == null) return null;
  final lines = <String>[];
  for (var line in raw.split('\n')) {
    line = line.trim();
    if (line.startsWith('///')) {
      line = line.substring(3);
    } else if (line.startsWith('/**')) {
      line = line.substring(3);
    } else if (line.startsWith('*')) {
      line = line.substring(1);
    }
    if (line.endsWith('*/')) {
      line = line.substring(0, line.length - 2);
    }
    line = line.replaceAll(RegExp(r'\{@\w+[^}]*\}'), '').trim();
    if (line.isNotEmpty) lines.add(line);
  }
  final joined = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return joined.isEmpty ? null : joined;
}

/// Splits a camelCase identifier into lowercase words: `imageUrl` →
/// `image url`.
String humanize(String identifier) {
  final withoutUnderscores = identifier.replaceAll('_', ' ').trim();
  final spaced = withoutUnderscores.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => ' ${m[1]}',
  );
  return spaced.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
