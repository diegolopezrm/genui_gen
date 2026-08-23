import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('actions', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A tappable card.')
class TapCard extends StatelessWidget {
  const TapCard({
    super.key,
    /// Fired when the card is tapped.
    this.onTap,
    @GenUiAction(eventName: 'confirm_pressed', description: 'Confirms.')
    required this.onConfirm,
    this.onDismiss,
  });

  final VoidCallback? onTap;
  final void Function() onConfirm;

  @GenUiAction(eventName: 'dismissed')
  final void Function()? onDismiss;
}
''');
    });

    test('schema uses A2uiSchemas.action', () {
      expect(
        out,
        contains(
          "'onTap': A2uiSchemas.action(description: 'Fired when the card is tapped.')",
        ),
      );
      expect(
        out,
        contains("'onConfirm': A2uiSchemas.action(description: 'Confirms.')"),
      );
      expect(out, contains("'onDismiss': A2uiSchemas.action()"));
      expect(out, contains("required: ['onConfirm']"));
    });

    test('callbacks go through genUiActionHandler', () {
      expect(out, contains("onTap: genUiActionHandler(ctx, data['onTap'])"));
      expect(
        out,
        contains("onDismiss: genUiActionHandler(ctx, data['onDismiss'])"),
      );
      expect(
        out,
        contains(
          "genUiActionHandler(ctx, data['onConfirm']) ?? "
          "missing<void Function()>('onConfirm', () {})",
        ),
      );
    });

    test('example event names default to the parameter name', () {
      expect(out, contains('"onTap":{"event":{"name":"onTap"}}'));
      expect(out, contains('"onConfirm":{"event":{"name":"confirm_pressed"}}'));
      expect(out, contains('"onDismiss":{"event":{"name":"dismissed"}}'));
    });

    test('actions alone do not need GenUiBindings', () {
      expect(out, isNot(contains('GenUiBindings(')));
    });
  });
}
