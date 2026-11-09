import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:genui_gen/genui_gen.dart';

import '../main.dart';

/// Every component the model may ask for, rendered from the example the
/// generator derived from each widget's constructor.
///
/// This is the catalog as the agent sees it: the same names, the same
/// properties, the same examples that go into the prompt.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final MessageProcessor<ComponentImplementation> _processor;
  late final Subscription _actions;

  /// The generated items, each with the surface of every example it carries.
  final List<(CatalogItem, List<SurfaceModel<ComponentImplementation>>)>
  _items = [];

  @override
  void initState() {
    super.initState();
    _processor = MessageProcessor<ComponentImplementation>(
      catalogs: [exampleCatalog],
      reportErrorsOnly: true,
    );
    final String version = A2uiProtocolVersion.v0_9.jsonValue;
    _actions = _processor.model.onAction.subscribe(
      (A2uiRendererAction action) => _show(
        jsonEncode(ActionMessage(version: version, action: action).toJson()),
      ),
    );
    for (final CatalogItem item
        in exampleCatalog.components.values.whereType<CatalogItem>()) {
      final surfaces = <SurfaceModel<ComponentImplementation>>[];
      for (var i = 0; i < item.exampleData.length; i++) {
        final String surfaceId = '${item.name}-$i';
        _processor.processMessages([
          {
            'version': version,
            'createSurface': {
              'surfaceId': surfaceId,
              'catalogId': exampleCatalog.id,
            },
          },
          {
            'version': version,
            'updateComponents': {
              'surfaceId': surfaceId,
              'components': jsonDecode(item.exampleData[i]()),
            },
          },
        ]);
        final SurfaceModel<ComponentImplementation>? surface = _processor.model
            .getSurface(surfaceId);
        if (surface != null) surfaces.add(surface);
      }
      _items.add((item, surfaces));
    }
  }

  @override
  void dispose() {
    _actions.unsubscribe();
    _processor.dispose();
    super.dispose();
  }

  void _show(String interaction) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(interaction)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (item, surfaces) in _items) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(item.name, style: theme.textTheme.titleMedium),
          ),
          for (final surface in surfaces)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: A2uiSurface(key: ObjectKey(surface), surface: surface),
              ),
            ),
        ],
      ],
    );
  }
}
