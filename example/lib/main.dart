import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
// ignore: deprecated_member_use, until Flutter stable has package:material_ui.
import 'package:flutter/material.dart';
import 'package:genui_gen/tracing.dart';

import 'genui_catalog.g.dart';
import 'pages/catalog_page.dart';
import 'pages/session_page.dart';
import 'pages/trace_page.dart';

void main() {
  runApp(const GenUiGenExampleApp());
}

/// The catalog the surfaces are built against: every generated component in
/// this app, next to the basic catalog's, so the agent can compose them with
/// core components such as `Text`.
///
/// `genUiCatalog` comes from `genui_catalog.g.dart`, which the builder
/// rewrites whenever a `@GenUiWidget` is added or removed, and carries the
/// `catalog_id` set in `build.yaml` and the instructions that show the agent
/// an example of each component. Adding a widget is one file; nothing here
/// has to be touched.
final CatalogImplementation exampleCatalog = basicCatalog().derive(
  catalogId: genUiCatalog.id,
  addComponents: genUiCatalogItems,
  // The generated functions join the basic ones, which `derive` keeps: a
  // `checks` rule calls them, and without them `{"call": "required"}` names
  // a function nobody registered.
  addFunctions: genUiCatalogFunctions,
  instructions: genUiCatalog.instructions,
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
