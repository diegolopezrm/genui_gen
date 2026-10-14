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

/// Every [ComponentImplementation] generated in this package,
/// by name.
///
/// Rebuilt whenever a `@GenUiWidget` is added, renamed or
/// removed, so a catalog composed from it cannot fall behind
/// the widgets it is meant to describe.
final List<ComponentImplementation> genUiCatalogItems =
    <ComponentImplementation>[
      labeledFieldCatalogItem,
      metricsTableCatalogItem,
      panelCatalogItem,
      preferenceRowCatalogItem,
      productCardCatalogItem,
      statTileCatalogItem,
      tagRowCatalogItem,
      taskListCatalogItem,
    ];

/// Every [FunctionImplementation] generated in this package,
/// by name.
///
/// These are the other half of a catalog: what the agent
/// computes a value with, through the `{"call": ...}` form
/// any dynamic property accepts.
final List<FunctionImplementation> genUiCatalogFunctions =
    <FunctionImplementation>[
      describeMetricGenUiFunction,
      formatPriceGenUiFunction,
      shortenNameGenUiFunction,
    ];

/// Every generated component and function of this package,
/// as a catalog ready to hand to a `MessageProcessor`.
///
/// A v0.9 surface draws on one catalog, so an agent that also
/// uses the basic components needs them in the same one:
///
/// ```dart
/// final catalog = CatalogImplementation(
///   id: genUiCatalog.id,
///   components: [...BasicComponents.all, ...genUiCatalogItems],
///   functions: [
///     ...BasicCatalog.v0_9().functions.values,
///     ...genUiCatalogFunctions,
///   ],
///   themeSchema: BasicComponents.api.themeSchema,
/// );
/// ```
final CatalogImplementation genUiCatalog = CatalogImplementation(
  id: 'dev.dlsoft.genui_gen.example',
  components: genUiCatalogItems,
  functions: genUiCatalogFunctions,
);
