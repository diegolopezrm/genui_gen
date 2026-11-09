import 'package:test/test.dart';

import 'src/harness.dart';

void main() {
  group('child components', () {
    late String out;

    setUpAll(() async {
      out = await generate('''
@GenUiWidget(description: 'A panel.')
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    /// Main content.
    required this.body,
    this.footer,
    required this.actions,
    this.extras,
    this.badges = const <Widget>[],
  });

  final Widget body;
  final Widget? footer;
  final List<Widget> actions;
  final List<Widget>? extras;
  final List<Widget> badges;
}
''');
    });

    test('schema uses ComponentId and lists of it', () {
      expect(
        out,
        contains(
          "'body': S.fromMap({...CommonSchemas.componentId.value, "
          "'description': 'Main content.'})",
        ),
      );
      expect(out, contains("'footer': CommonSchemas.componentId,"));
      expect(
        out,
        contains("'actions': S.list(items: CommonSchemas.componentId)"),
      );
      expect(
        out,
        contains("'extras': S.list(items: CommonSchemas.componentId)"),
      );
      expect(out, contains("required: ['body', 'actions']"));
    });

    test('children are built straight from the resolved properties', () {
      expect(out, contains('return Panel('));
      expect(out, isNot(contains('data[')));
    });

    test('single children build the node the renderer resolved', () {
      expect(
        out,
        contains(
          "body: switch (props.child('body')) {final child? => "
          "buildChild(child), _ => missing<Widget>('body', "
          'const SizedBox.shrink())}',
        ),
      );
      expect(
        out,
        contains(
          "footer: switch (props.child('footer')) {final child? => "
          'buildChild(child), _ => null}',
        ),
      );
    });

    test('child lists build one child per node', () {
      expect(out, contains("actions: props.value('actions') is List"));
      expect(
        out,
        contains(
          "[for (final child in props.children('actions')) buildChild(child)]",
        ),
      );
      expect(
        out,
        contains("missing<List<Widget>>('actions', const <Widget>[])"),
      );
      expect(out, contains("badges: props.value('badges') is List"));
      expect(out, contains(': const <Widget>[])'));
    });

    test('example references Text components for children', () {
      expect(out, contains('"body":"child_body"'));
      expect(
        out,
        contains('{"id":"child_body","component":"Text","text":"Sample body"}'),
      );
      expect(out, contains('"actions":["child_actions_1","child_actions_2"]'));
      expect(
        out,
        contains(
          '{"id":"child_actions_1","component":"Text","text":"Sample actions 1"}',
        ),
      );
      expect(
        out,
        contains(
          '{"id":"child_actions_2","component":"Text","text":"Sample actions 2"}',
        ),
      );
    });
  });

  test(
    'mixed bound and child properties keep children outside bindings',
    () async {
      final out = await generate('''
@GenUiWidget(description: 'Titled box.')
class TitledBox extends StatelessWidget {
  const TitledBox({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
}
''');
      expect(out, contains("title: genUiAsString(props.value('title'))"));
      expect(out, contains("child: switch (props.child('child'))"));
      expect(out, isNot(contains("props.value('child')")));
      expect(out, contains('return TitledBox('));
    },
  );
}
