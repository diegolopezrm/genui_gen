import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// Renders one catalog item's generated example, through a real surface.
///
/// The example is the only sample of a component the package has that the
/// model also sees: it is what few-shot prompting shows the model and what
/// `DebugCatalogView` puts on screen. Rendering it through a
/// [SurfaceController], rather than calling the widget directly, is what makes
/// a test of it a test of the whole path — schema, bindings, actions and all.
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
  /// It needs a `catalogId`, since a surface names the catalog it was built
  /// against; `genUiCatalog` carries the one from `build.yaml`.
  final Catalog catalog;

  /// The item whose example is rendered.
  final CatalogItem item;

  /// Which of [CatalogItem.exampleData] to render, for an item that declares
  /// more than one.
  final int exampleIndex;

  @override
  State<GenUiExampleSurface> createState() => _GenUiExampleSurfaceState();
}

class _GenUiExampleSurfaceState extends State<GenUiExampleSurface> {
  late SurfaceController _controller;
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
      // After the frame, not during it: the widgets the old controller built
      // are still mounted, and some of them read inherited widgets as they go
      // away.
      final SurfaceController previous = _controller;
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _start();
    }
  }

  void _start() {
    _controller = SurfaceController(catalogs: [widget.catalog]);
    _surfaceId = '${widget.item.name}-${widget.exampleIndex}';

    final String catalogId = widget.catalog.catalogId!;
    final List<JsonMap> components =
        (jsonDecode(widget.item.exampleData[widget.exampleIndex]()) as List)
            .cast<JsonMap>();

    _controller.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: _surfaceId,
        components: components,
      ),
    );
    _controller.handleMessage(
      core.CreateSurfaceMessage(surfaceId: _surfaceId, catalogId: catalogId),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Surface(surfaceContext: _controller.contextFor(_surfaceId));
}
