// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:genui/genui.dart';

import 'main.dart';

/// Every [CatalogItem] generated in this package, by name.
///
/// Rebuilt whenever a `@GenUiWidget` is added, renamed or
/// removed, so a catalog composed from it cannot fall behind
/// the widgets it is meant to describe.
final List<CatalogItem> genUiCatalogItems = <CatalogItem>[
  productCardCatalogItem,
];

/// Every [ClientFunction] generated in this package, by
/// name.
///
/// These are the other half of a catalog: what the model
/// computes a value with, through the `{"call": ...}` form
/// any bound property accepts.
final List<ClientFunction> genUiCatalogFunctions = <ClientFunction>[];

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
///   newFunctions: BasicCatalogItems.asCatalog().functions.toList(),
/// );
/// ```
///
/// This catalog has no id, because no `catalog_id`
/// build option was set. A surface names the catalog it
/// was built against, so set one in `build.yaml` before
/// talking to an agent:
///
/// ```yaml
/// targets:
///   $default:
///     builders:
///       genui_gen_builder:genui_catalog:
///         options:
///           catalog_id: com.example.my_catalog
/// ```
final Catalog genUiCatalog = Catalog(
  genUiCatalogItems,
  functions: genUiCatalogFunctions,
);
