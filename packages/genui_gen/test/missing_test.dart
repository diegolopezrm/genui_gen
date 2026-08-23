import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

CatalogItemContext contextFor({
  required Object data,
  required void Function(Object error, StackTrace? stack) reportError,
  String id = 'card-1',
  String surfaceId = 'surface-1',
  required BuildContext buildContext,
  required DataContext dataContext,
}) => CatalogItemContext(
  data: data,
  id: id,
  type: 'ProductCard',
  buildChild: (_, [_]) => const SizedBox.shrink(),
  dispatchEvent: (_) {},
  buildContext: buildContext,
  dataContext: dataContext,
  getComponent: (_) => null,
  getCatalogItem: (_) => null,
  surfaceId: surfaceId,
  reportError: reportError,
);

void main() {
  late InMemoryDataModel model;
  late DataContext dataContext;
  late List<Object> errors;

  setUp(() {
    genUiResetMissingReports();
    model = InMemoryDataModel();
    dataContext = DataContext(model, DataPath.root);
    errors = <Object>[];
  });

  tearDown(() {
    model.dispose();
  });

  Future<void> pump(
    WidgetTester tester,
    void Function(CatalogItemContext ctx) body, {
    Object data = const <String, Object?>{},
    String id = 'card-1',
  }) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          body(
            contextFor(
              data: data,
              id: id,
              reportError: (error, _) => errors.add(error),
              buildContext: context,
              dataContext: dataContext,
            ),
          );
          return const SizedBox.shrink();
        },
      ),
    );
  }

  testWidgets('reports an omitted literal as A2uiValidationException', (
    tester,
  ) async {
    await pump(tester, (ctx) {
      genUiReportMissing(ctx, 'ProductCard', 'title');
    });

    expect(errors, hasLength(1));
    final error = errors.single;
    expect(error, isA<A2uiValidationException>());
    error as A2uiValidationException;
    expect(error.message, contains('ProductCard'));
    expect(error.message, contains('"title"'));
    expect(error.surfaceId, 'surface-1');
    expect(error.path, 'title');
  });

  testWidgets('does not report a path binding that resolves to null', (
    tester,
  ) async {
    await pump(
      tester,
      (ctx) => genUiReportMissing(ctx, 'ProductCard', 'title'),
      data: const {
        'title': {'path': '/product/title'},
      },
    );
    expect(errors, isEmpty);
  });

  testWidgets('does not report a function call binding', (tester) async {
    await pump(
      tester,
      (ctx) => genUiReportMissing(ctx, 'ProductCard', 'title'),
      data: const {
        'title': {'call': 'loadTitle'},
      },
    );
    expect(errors, isEmpty);
  });

  testWidgets('reports a literal of the wrong shape', (tester) async {
    await pump(
      tester,
      (ctx) => genUiReportMissing(ctx, 'ProductCard', 'title'),
      data: const {
        'title': {'unexpected': 1},
      },
    );
    expect(errors, hasLength(1));
  });

  testWidgets('reports once per component instance across rebuilds', (
    tester,
  ) async {
    void report(CatalogItemContext ctx) {
      genUiReportMissing(ctx, 'ProductCard', 'title');
    }

    await pump(tester, report);
    await pump(tester, report);
    await pump(tester, report, id: 'card-2');

    expect(errors, hasLength(2));
  });

  testWidgets('swallows errors thrown by reportError', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final ctx = contextFor(
            data: const <String, Object?>{},
            reportError: (_, _) => throw StateError('reporting failed'),
            buildContext: context,
            dataContext: dataContext,
          );
          expect(
            () => genUiReportMissing(ctx, 'ProductCard', 'title'),
            returnsNormally,
          );
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
