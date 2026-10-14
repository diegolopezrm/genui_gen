import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'component.dart';

/// Renders one generated component's example, through a real surface.
///
/// The example is the sample of a component the agent also sees, in the
/// catalog's instructions. Rendering it through a [MessageProcessor] and an
/// [A2uiSurface], rather than calling the widget directly, is what makes a
/// test of it a test of the whole path: the schema the message is validated
/// against, the bindings, the actions and the widget.
///
/// A message the catalog rejects throws while this widget is built, which a
/// test reports as the failure it is.
class GenUiExampleSurface extends StatefulWidget {
  /// Creates a [GenUiExampleSurface].
  const GenUiExampleSurface({
    super.key,
    required this.catalog,
    required this.component,
    this.exampleIndex = 0,
    this.onAction,
  });

  /// The catalog the example is composed against.
  ///
  /// A v0.9 surface draws on one catalog, so it holds the basic components an
  /// example composes with, such as the `Text` of a child.
  final CatalogImplementation catalog;

  /// The component whose example is rendered.
  final GenUiComponent component;

  /// Which of [GenUiComponent.examples] to render, for a component that has
  /// more than one.
  final int exampleIndex;

  /// Called with each action the example sends, such as a button press, which
  /// an app would hand to the agent.
  final ValueChanged<A2uiClientAction>? onAction;

  @override
  State<GenUiExampleSurface> createState() => _GenUiExampleSurfaceState();
}

class _GenUiExampleSurfaceState extends State<GenUiExampleSurface> {
  late MessageProcessor<ComponentImplementation> _processor;
  late SurfaceModel<ComponentImplementation> _surface;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(GenUiExampleSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rendering a second component in the place of the first, as a test
    // walking the catalog does, reuses this State, so without this the
    // surface would keep showing the example it was built with.
    if (oldWidget.component != widget.component ||
        oldWidget.exampleIndex != widget.exampleIndex ||
        oldWidget.catalog != widget.catalog) {
      // After the frame, not during it: the widgets the old surface built are
      // still mounted, and some of them read inherited widgets as they go.
      final MessageProcessor<ComponentImplementation> previous = _processor;
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _start();
    }
  }

  void _start() {
    _processor = MessageProcessor<ComponentImplementation>(
      catalogs: [widget.catalog],
      defaultVersion: A2uiProtocolVersion.v0_9,
    );
    // Read when the action arrives, so a rebuilt widget's callback is the one
    // called.
    _processor.groupModel.onAction.addListener(
      (action) => widget.onAction?.call(action),
    );
    final surfaceId = '${widget.component.name}-${widget.exampleIndex}';
    final Object? components = jsonDecode(
      widget.component.examples[widget.exampleIndex],
    );
    _processor.processMessages(<Object?>[
      {
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': surfaceId,
          'catalogId': widget.catalog.id,
        },
      },
      {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': surfaceId, 'components': components},
      },
    ]);
    _surface = _processor.groupModel.getSurface(surfaceId)!;
  }

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      A2uiSurface(key: ObjectKey(_surface), surface: _surface);
}
