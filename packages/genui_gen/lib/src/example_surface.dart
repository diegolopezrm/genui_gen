import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'catalog_item.dart';

/// Renders one catalog item's generated example, through a real surface.
///
/// The example is the only sample of a component the package has that is
/// written the way the model writes it: it is what few-shot prompting shows
/// the model and what a catalog page puts on screen. Rendering it through a
/// [MessageProcessor] and an [A2uiSurface], rather than calling the widget
/// directly, is what makes a test of it a test of the whole path — schema,
/// bindings, actions and all.
class GenUiExampleSurface extends StatefulWidget {
  /// Creates a [GenUiExampleSurface].
  const GenUiExampleSurface({
    super.key,
    required this.catalog,
    required this.item,
    this.exampleIndex = 0,
  });

  /// The catalog the example is composed against.
  ///
  /// A surface names the catalog it was built against, and the example is
  /// created against this one's id. It has to hold every component the
  /// example names, which for a generated example includes the basic `Text`.
  final CatalogImplementation catalog;

  /// The item whose example is rendered.
  final CatalogItem item;

  /// Which of [CatalogItem.exampleData] to render, for an item that declares
  /// more than one.
  final int exampleIndex;

  @override
  State<GenUiExampleSurface> createState() => _GenUiExampleSurfaceState();
}

class _GenUiExampleSurfaceState extends State<GenUiExampleSurface> {
  late MessageProcessor<ComponentImplementation> _processor;
  late String _surfaceId;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(GenUiExampleSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rendering a second item in the place of the first — a test walking the
    // catalog does exactly that — reuses this State, so without this the
    // surface would keep showing the example it was built with.
    if (oldWidget.item != widget.item ||
        oldWidget.exampleIndex != widget.exampleIndex ||
        oldWidget.catalog != widget.catalog) {
      // After the frame, not during it: the widgets the old processor built
      // are still mounted, and some of them read inherited widgets as they go
      // away.
      final MessageProcessor<ComponentImplementation> previous = _processor;
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _start();
    }
  }

  void _start() {
    // An example the catalog rejects is reported on the processor's `onError`
    // rather than thrown from `initState`, and renders nothing.
    _processor = MessageProcessor<ComponentImplementation>(
      catalogs: [widget.catalog],
      reportErrorsOnly: true,
    );
    _surfaceId = '${widget.item.name}-${widget.exampleIndex}';

    final String version = A2uiProtocolVersion.v0_9.jsonValue;
    final List<Object?> components =
        jsonDecode(widget.item.exampleData[widget.exampleIndex]()) as List;

    _processor.processMessages(<Object?>[
      <String, Object?>{
        'version': version,
        'createSurface': <String, Object?>{
          'surfaceId': _surfaceId,
          'catalogId': widget.catalog.id,
        },
      },
      <String, Object?>{
        'version': version,
        'updateComponents': <String, Object?>{
          'surfaceId': _surfaceId,
          'components': components,
        },
      },
    ]);
  }

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SurfaceModel<ComponentImplementation>? surface = _processor.model
        .getSurface(_surfaceId);
    if (surface == null) return const SizedBox.shrink();
    return A2uiSurface(key: ObjectKey(surface), surface: surface);
  }
}
