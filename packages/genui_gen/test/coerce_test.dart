import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  group('genUiAsString', () {
    test('passes a String through and renders anything else', () {
      expect(genUiAsString('hi'), 'hi');
      expect(genUiAsString(42), '42');
      expect(genUiAsString(true), 'true');
      expect(genUiAsString(null), isNull);
    });
  });

  group('genUiAsNum', () {
    test('parses a numeric String and rejects the rest', () {
      expect(genUiAsNum(42), 42);
      expect(genUiAsNum(42.5), 42.5);
      expect(genUiAsNum('42.5'), 42.5);
      expect(genUiAsNum('nope'), isNull);
      expect(genUiAsNum(true), isNull);
      expect(genUiAsNum(null), isNull);
    });
  });

  group('genUiAsBool', () {
    test('accepts the forms genui accepts', () {
      expect(genUiAsBool(true), isTrue);
      expect(genUiAsBool('TRUE'), isTrue);
      expect(genUiAsBool('false'), isFalse);
      expect(genUiAsBool(1), isTrue);
      expect(genUiAsBool(0), isFalse);
      expect(genUiAsBool('maybe'), isNull);
      expect(genUiAsBool(null), isNull);
    });
  });

  group('genUiAsStringList', () {
    test('renders entries and drops nulls', () {
      expect(genUiAsStringList(<Object?>['a', 1, null, true]), <String>[
        'a',
        '1',
        'true',
      ]);
      expect(genUiAsStringList('a'), isNull);
      expect(genUiAsStringList(null), isNull);
    });
  });

  group('genUiAsObject', () {
    test('rebuilds a map with non-String keys', () {
      expect(genUiAsObject(<String, Object?>{'a': 1}), <String, Object?>{
        'a': 1,
      });
      expect(genUiAsObject(<Object?, Object?>{1: 'a'}), <String, Object?>{
        '1': 'a',
      });
      expect(genUiAsObject(<Object?>[]), isNull);
      expect(genUiAsObject('a'), isNull);
    });
  });

  group('genUiAsObjectList', () {
    test('keeps the maps and skips everything else', () {
      expect(
        genUiAsObjectList(<Object?>[
          <String, Object?>{'a': 1},
          'junk',
          <Object?, Object?>{2: 'b'},
        ]),
        <Map<String, Object?>>[
          <String, Object?>{'a': 1},
          <String, Object?>{'2': 'b'},
        ],
      );
      expect(genUiAsObjectList(<String, Object?>{}), isNull);
      expect(genUiAsObjectList(null), isNull);
    });
  });

  group('field reporting', () {
    test('genUiMissingField reports and returns the fallback', () {
      final List<String> reported = <String>[];
      expect(genUiMissingField<String>(reported.add, 'label', ''), '');
      expect(reported, <String>['label']);
    });

    test('genUiMissingField tolerates a null reporter', () {
      expect(genUiMissingField<num>(null, 'value', 0), 0);
    });

    test('genUiNestedField prefixes the field name', () {
      final List<String> reported = <String>[];
      final GenUiMissingFieldReporter? nested = genUiNestedField(
        reported.add,
        'badge',
      );
      nested!('text');
      expect(reported, <String>['badge.text']);
    });

    test('genUiNestedField allocates nothing without a reporter', () {
      expect(genUiNestedField(null, 'badge'), isNull);
    });
  });
}
