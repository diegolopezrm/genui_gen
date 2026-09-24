import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/tracing.dart';

import 'genui_catalog.g.dart';
import 'pages/catalog_page.dart';
import 'pages/session_page.dart';
import 'pages/trace_page.dart';

void main() {
  runApp(const GenUiGenExampleApp());
}

/// The catalog handed to genui: every generated item in this app, plus genui's
/// basic catalog so the generated examples can reference core components such
/// as `Text`.
///
/// `genUiCatalog` comes from `genui_catalog.g.dart`, which the builder
/// rewrites whenever a `@GenUiWidget` is added or removed, and carries the
/// `catalog_id` set in `build.yaml`. Adding a widget is one file; nothing here
/// has to be touched.
final Catalog exampleCatalog = genUiCatalog.copyWith(
  newItems: BasicCatalogItems.asCatalog().items.toList(),
);

/// The session recorded in the Session tab, for the Trace tab to replay.
///
/// A real app writes this to a file and attaches it to a bug report. Here it
/// stays in memory so the two tabs can be looked at side by side.
final ValueNotifier<GenUiTrace?> recordedTrace = ValueNotifier<GenUiTrace?>(
  null,
);

/// Three tabs, one per thing the package does: describe a catalog, run a
/// session against it, and replay the session afterwards.
class GenUiGenExampleApp extends StatelessWidget {
  const GenUiGenExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'genui_gen example',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('genui_gen'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.widgets_outlined), text: 'Catalog'),
                Tab(icon: Icon(Icons.forum_outlined), text: 'Session'),
                Tab(icon: Icon(Icons.history), text: 'Trace'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [CatalogPage(), SessionPage(), TracePage()],
          ),
        ),
      ),
    );
  }
}
