// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:genui/genui.dart';

import 'functions/text_functions.dart';
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
  metricsTableCatalogItem,
  panelCatalogItem,
  preferenceRowCatalogItem,
  productCardCatalogItem,
  statTileCatalogItem,
  tagRowCatalogItem,
  taskListCatalogItem,
];

/// Every [ClientFunction] generated in this package, by
/// name.
///
/// These are the other half of a catalog: what the model
/// computes a value with, through the `{"call": ...}` form
/// any bound property accepts.
final List<ClientFunction> genUiCatalogFunctions = <ClientFunction>[
  formatPriceGenUiFunction,
  shortenNameGenUiFunction,
];

/// Every generated [CatalogItem] of this package, as a
/// [Catalog] ready to hand to genui.
///
/// Compose it with any other catalog through
/// [Catalog.copyWith], for instance to add genui's own
/// basic components:
///
/// ```dart
/// final catalog = genUiCatalog.copyWith(
///   newItems: BasicCatalogItems.asCatalog().items.toList(),
/// );
/// ```
final Catalog genUiCatalog = Catalog(
  genUiCatalogItems,
  functions: genUiCatalogFunctions,
  catalogId: 'dev.dlsoft.genui_gen.example',
);
