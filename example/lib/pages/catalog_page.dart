import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui_gen/inspector.dart';

import '../main.dart';

/// Every component the agent may ask for, rendered from the example the
/// generator derived from each widget's constructor.
///
/// This is the catalog as the agent sees it: the same names, the same
/// properties, the same examples that go into its instructions.
class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GenUiCatalogView(
      catalog: exampleCatalog,
      onAction: (action) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(jsonEncode({'action': action.toJson()}))),
        ),
    );
  }
}
