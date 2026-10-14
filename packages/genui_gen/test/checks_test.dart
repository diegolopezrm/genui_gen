import 'package:flutter_test/flutter_test.dart';
import 'package:genui_gen/genui_gen.dart';

void main() {
  test('two results that say the same thing are equal', () {
    expect(
      const GenUiCheckResult(isValid: false, message: 'Too short.'),
      const GenUiCheckResult(isValid: false, message: 'Too short.'),
    );
    expect(
      const GenUiCheckResult(isValid: false, message: 'Too short.').hashCode,
      const GenUiCheckResult(isValid: false, message: 'Too short.').hashCode,
    );
    expect(
      const GenUiCheckResult(isValid: false, message: 'Too short.'),
      isNot(GenUiCheckResult.valid),
    );
  });

  test('reads as what it says', () {
    expect(GenUiCheckResult.valid.toString(), 'valid');
    expect(
      const GenUiCheckResult(isValid: false, message: 'Too short.').toString(),
      'invalid: Too short.',
    );
  });
}
