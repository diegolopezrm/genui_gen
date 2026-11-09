// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:genui_gen/genui_gen.dart';

import 'functions/text_functions.dart';
import 'widgets/labeled_field.dart';
import 'widgets/metrics_table.dart';
import 'widgets/panel.dart';
import 'widgets/preference_row.dart';
import 'widgets/product_card.dart';
import 'widgets/stat_tile.dart';
import 'widgets/tag_row.dart';
import 'widgets/task_list.dart';

/// Every [CatalogItem] generated in this package, by name.
///
/// Rebuilt whenever a `@GenUiWidget` is added, renamed or
/// removed, so a catalog composed from it cannot fall behind
/// the widgets it is meant to describe.
final List<CatalogItem> genUiCatalogItems = <CatalogItem>[
  labeledFieldCatalogItem,
  metricsTableCatalogItem,
  panelCatalogItem,
  preferenceRowCatalogItem,
  productCardCatalogItem,
  statTileCatalogItem,
  tagRowCatalogItem,
  taskListCatalogItem,
];

/// Every [FunctionImplementation] generated in this
/// package, by name.
///
/// These are the other half of a catalog: what the model
/// computes a value with, through the `{"call": ...}` form
/// any bound property accepts.
final List<FunctionImplementation> genUiCatalogFunctions =
    <FunctionImplementation>[
      describeMetricGenUiFunction,
      formatPriceGenUiFunction,
      shortenNameGenUiFunction,
    ];

/// Every generated [CatalogItem] of this package, as a
/// [CatalogImplementation] ready to hand to the renderer.
///
/// A v0.9 surface draws on one catalog, so add a2ui_flutter's
/// basic components by deriving its basic catalog
/// (`package:a2ui_flutter/v0_9/basic_catalog.dart`):
///
/// ```dart
/// final catalog = basicCatalog().derive(
///   catalogId: genUiCatalog.id,
///   addComponents: genUiCatalogItems,
///   addFunctions: genUiCatalogFunctions,
/// );
/// ```
final CatalogImplementation genUiCatalog = CatalogImplementation(
  id: 'dev.dlsoft.genui_gen.example',
  components: genUiCatalogItems,
  functions: genUiCatalogFunctions,
);
