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

    test('schema uses componentReference and lists of it', () {
      expect(
        out,
        contains(
          "'body': A2uiSchemas.componentReference(description: 'Main content.')",
        ),
      );
      expect(out, contains("'footer': A2uiSchemas.componentReference()"));
      expect(
        out,
        contains("'actions': S.list(items: A2uiSchemas.componentReference())"),
      );
      expect(
        out,
        contains("'extras': S.list(items: A2uiSchemas.componentReference())"),
      );
      expect(out, contains("required: ['body', 'actions']"));
    });

    test('children are not bound, so no GenUiBindings wrapper is needed', () {
      expect(out, isNot(contains('GenUiBindings(')));
      expect(out, contains('return Panel('));
    });

    test('single children build through ctx.buildChild', () {
      expect(out, contains("final _body = data['body'];"));
      expect(out, contains('body: _body is String'));
      expect(out, contains('ctx.buildChild(_body)'));
      expect(out, contains("missing<Widget>('body', const SizedBox.shrink())"));
      expect(
        out,
        contains('footer: _footer is String ? ctx.buildChild(_footer) : null'),
      );
    });

    test('child lists map ids through ctx.buildChild', () {
      expect(out, contains("final _actions = data['actions'];"));
      expect(out, contains('actions: _actions is List'));
      expect(
        out,
        contains(
          '.whereType<String>().map((id) => ctx.buildChild(id)).toList()',
        ),
      );
      expect(
        out,
        contains("missing<List<Widget>>('actions', const <Widget>[])"),
      );
      expect(out, contains('badges: _badges is List'));
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
      expect(out, contains("final _child = data['child'];"));
      expect(out, contains('return GenUiBindings('));
      expect(out, contains("'title': GenUiBinding.string(data['title'])"));
      expect(out, isNot(contains("'child': GenUiBinding")));
      expect(out, contains('builder: (context, v) => TitledBox('));
    },
  );
}
