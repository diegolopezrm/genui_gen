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

    test('schema uses the common Action type', () {
      expect(
        out,
        contains(
          "'onTap': S.fromMap({...CommonSchemas.action.value, "
          "'description': 'Fired when the card is tapped.'})",
        ),
      );
      expect(
        out,
        contains(
          "'onConfirm': S.fromMap({...CommonSchemas.action.value, "
          "'description': 'Confirms.'})",
        ),
      );
      expect(out, contains("'onDismiss': CommonSchemas.action}"));
      expect(out, contains("required: ['onConfirm']"));
    });

    test('callbacks go through genUiActionHandler', () {
      expect(out, contains("onTap: genUiActionHandler(props.action('onTap'))"));
      expect(
        out,
        contains("onDismiss: genUiActionHandler(props.action('onDismiss'))"),
      );
      expect(
        out,
        contains(
          "genUiActionHandler(props.action('onConfirm')) ?? "
          "missing<void Function()>('onConfirm', () {})",
        ),
      );
    });

    test('example event names default to the parameter name', () {
      expect(out, contains('"onTap":{"event":{"name":"onTap"}}'));
      expect(out, contains('"onConfirm":{"event":{"name":"confirm_pressed"}}'));
      expect(out, contains('"onDismiss":{"event":{"name":"dismissed"}}'));
    });

    test('actions are read from the resolved properties, not the raw data', () {
      expect(out, isNot(contains('data[')));
    });
  });
}
