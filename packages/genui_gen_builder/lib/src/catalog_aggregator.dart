/// Emits one `lib/genui_catalog.g.dart` per package, listing every
/// `CatalogItem` the per-library generator produced.
///
/// Registering a catalog is otherwise a hand-maintained import list plus a
/// hand-maintained list of variable names, which is the same drift this
/// package exists to remove, one level up: add a `@GenUiWidget` and the
/// catalog silently stays as it was.
library;

import 'dart:async';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import 'generator.dart' show generatedPartExtension;
import 'renderer.dart';
import 'spec.dart' show lowerCamel;
import 'strings.dart' show generatedFileHeader;

/// The file emitted at the root of the package's `lib/`.
const aggregateFileName = 'genui_catalog.g.dart';

/// The variable the emitted file declares.
const aggregateVariableName = 'genUiCatalogItems';

/// The name of the generated list of `ClientFunction`s.
const aggregateFunctionsVariableName = 'genUiCatalogFunctions';

/// The assembled [Catalog] the emitted file declares alongside the list.
const aggregateCatalogVariableName = 'genUiCatalog';

/// The `build.yaml` option that names the emitted catalog.
const catalogIdOption = 'catalog_id';

/// What a catalog id is allowed to contain.
///
/// Reverse-domain notation (`com.example.app`) is what A2UI recommends and a
/// URL is what its own basic catalog uses, so both have to pass. Everything
/// here lands inside a single-quoted Dart string as-is, so the characters that
/// would end that string or interpolate into it — quotes, `$`, backslashes,
/// newlines — are rejected rather than escaped.
final _catalogIdPattern = RegExp(r'^[A-Za-z0-9_.:/#?=&@%+~-]+$');

/// One generated catalog item, and where it came from.
final class _Item {
  _Item(this.variableName, this.libraryImport, this.assetPath);

  /// The generated top-level variable, e.g. `productCardCatalogItem`.
  final String variableName;

  /// The import the aggregate needs, relative to `lib/`.
  final String libraryImport;

  /// The `.genui.dart` asset it was read from, for diagnostics.
  final String assetPath;
}

/// Collects the generated catalog items of a package into a single library.
class CatalogAggregatingBuilder implements Builder {
  const CatalogAggregatingBuilder({this.catalogId});

  /// The id the emitted [Catalog] carries, from the `catalog_id` build option.
  ///
  /// A2UI names a catalog in `createSurface`, and genui's own
  /// `DebugCatalogView` refuses a catalog without an id, so an app that talks
  /// to an agent needs one. It cannot be derived here: the id identifies the
  /// catalog to everything outside this build, which only the author knows.
  final String? catalogId;

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': [aggregateFileName],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final items = <_Item>[];
    final functions = <_Item>[];
    final renderers = <Renderer, String>{};
    final assets = await buildStep
        .findAssets(Glob('lib/**$generatedPartExtension'))
        .toList();
    // Sorted so the emitted list does not reorder itself between builds.
    assets.sort((a, b) => a.path.compareTo(b.path));

    for (final asset in assets) {
      final source = await buildStep.readAsString(asset);
      final relative = asset.path.substring('lib/'.length);
      final libraryImport =
          '${relative.substring(0, relative.length - generatedPartExtension.length)}.dart';
      final Renderer? renderer = _rendererOf(source);
      if (renderer != null) renderers.putIfAbsent(renderer, () => asset.path);
      for (final name in _catalogItemNames(source)) {
        if (name.startsWith('_')) {
          // Reachable: `@GenUiWidget(name: 'Public')` on a private class passes
          // the generator's name check but produces a private variable, which
          // no other library can name.
          log.warning(
            'Skipping `$name` from ${asset.path} in $aggregateFileName: the '
            'variable is private, because the class it comes from is. Make '
            'the class public to have it listed.',
          );
          continue;
        }
        items.add(_Item(name, libraryImport, asset.path));
      }
      for (final name in _catalogFunctionNames(source)) {
        if (name.startsWith('_')) continue;
        functions.add(_Item(name, libraryImport, asset.path));
      }
    }

    // A package with nothing annotated gets no file, rather than an empty one
    // that looks like a mistake.
    if (items.isEmpty && functions.isEmpty) return;

    if (renderers.length > 1) {
      throw InvalidGenerationSourceError(
        '`${renderers[Renderer.genui]}` was generated for genui and '
        '`${renderers[Renderer.a2uiFlutter]}` for a2ui_flutter, so '
        '`$aggregateFileName` cannot put them in one catalog. Run '
        '`dart run build_runner build --delete-conflicting-outputs` to '
        'regenerate every part against the genui_gen this package resolves.',
      );
    }
    final Renderer renderer = renderers.keys.firstOrNull ?? Renderer.genui;

    _checkForClashes(items);
    _checkForClashes(functions);
    items.sort((a, b) => a.variableName.compareTo(b.variableName));
    functions.sort((a, b) => a.variableName.compareTo(b.variableName));

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/$aggregateFileName'),
      switch (renderer) {
        Renderer.genui => _emit(items, functions),
        Renderer.a2uiFlutter => _emitA2ui(items, functions),
      },
    );
  }

  /// Rejects two items that would arrive under the same name.
  ///
  /// The per-library generator already rejects a collision inside one library.
  /// Across libraries the two only meet here, where the aggregate imports both
  /// and names each unprefixed.
  void _checkForClashes(List<_Item> items) {
    final byName = <String, _Item>{};
    for (final item in items) {
      final previous = byName[item.variableName];
      if (previous != null) {
        throw InvalidGenerationSourceError(
          '`${previous.assetPath}` and `${item.assetPath}` both generate '
          '`${item.variableName}`, so `$aggregateFileName` cannot name them '
          'apart. Rename one of the classes, or give one a different '
          'component name and rename the class to match.',
        );
      }
      byName[item.variableName] = item;
    }
  }

  String _emit(List<_Item> items, List<_Item> functions) {
    final imports = {
      for (final item in items) item.libraryImport,
      for (final function in functions) function.libraryImport,
    }.toList()..sort();
    final out = StringBuffer()
      ..write(generatedFileHeader)
      ..writeln()
      // Only genui_gen, which re-exports the renderer types named below, so
      // the generated catalog follows genui_gen to whichever renderer it is
      // built on rather than naming genui itself.
      ..writeln("import 'package:genui_gen/genui_gen.dart';")
      ..writeln();
    for (final import in imports) {
      out.writeln("import '$import';");
    }
    out
      ..writeln()
      ..writeln('/// Every [CatalogItem] generated in this package, by name.')
      ..writeln('///')
      ..writeln('/// Rebuilt whenever a `@GenUiWidget` is added, renamed or')
      ..writeln('/// removed, so a catalog composed from it cannot fall behind')
      ..writeln('/// the widgets it is meant to describe.')
      ..writeln(
        'final List<CatalogItem> $aggregateVariableName = <CatalogItem>[',
      );
    for (final item in items) {
      out.writeln('  ${item.variableName},');
    }
    out.writeln('];');

    out
      ..writeln()
      ..writeln('/// Every [ClientFunction] generated in this package, by')
      ..writeln('/// name.')
      ..writeln('///')
      ..writeln('/// These are the other half of a catalog: what the model')
      ..writeln('/// computes a value with, through the `{"call": ...}` form')
      ..writeln('/// any bound property accepts.')
      ..writeln(
        'final List<ClientFunction> $aggregateFunctionsVariableName = '
        '<ClientFunction>[',
      );
    for (final function in functions) {
      out.writeln('  ${function.variableName},');
    }
    out.writeln('];');

    _writeCatalog(out);
    return out.toString();
  }

  /// The aggregate for a2ui_flutter: the components, the functions and, when
  /// the build names one, the catalog.
  ///
  /// The lists keep the names they have on genui, so an app that moves across
  /// changes the types it composes them into and nothing else.
  String _emitA2ui(List<_Item> items, List<_Item> functions) {
    final imports = {
      for (final item in items) item.libraryImport,
      for (final function in functions) function.libraryImport,
    }.toList()..sort();
    final out = StringBuffer()
      ..write(generatedFileHeader)
      ..writeln()
      ..writeln("import 'package:genui_gen/genui_gen.dart';")
      ..writeln();
    for (final import in imports) {
      out.writeln("import '$import';");
    }
    out
      ..writeln()
      ..writeln(
        '/// Every [ComponentImplementation] generated in this package,',
      )
      ..writeln('/// by name.')
      ..writeln('///')
      ..writeln('/// Rebuilt whenever a `@GenUiWidget` is added, renamed or')
      ..writeln('/// removed, so a catalog composed from it cannot fall behind')
      ..writeln('/// the widgets it is meant to describe.')
      ..writeln('final List<ComponentImplementation> $aggregateVariableName =');
    _writeList(out, 'ComponentImplementation', items);
    out
      ..writeln()
      ..writeln('/// Every [FunctionImplementation] generated in this package,')
      ..writeln('/// by name.')
      ..writeln('///')
      ..writeln('/// These are the other half of a catalog: what the agent')
      ..writeln('/// computes a value with, through the `{"call": ...}` form')
      ..writeln('/// any dynamic property accepts.')
      ..writeln(
        'final List<FunctionImplementation> $aggregateFunctionsVariableName =',
      );
    _writeList(out, 'FunctionImplementation', functions);

    final id = catalogId;
    if (id == null) {
      // A catalog cannot be built without an id on a2ui_core, unlike genui,
      // so there is no catalog to emit; the lists still are.
      log.warning(
        'No `$catalogIdOption` build option is set, so $aggregateFileName '
        'declares the generated components and functions but no '
        '`$aggregateCatalogVariableName`: an a2ui_flutter catalog needs an '
        'id. Set one under genui_gen_builder:genui_catalog in build.yaml.',
      );
      return out.toString();
    }
    _checkCatalogId(id);
    out
      ..writeln()
      ..writeln('/// Every generated component and function of this package,')
      ..writeln('/// as a catalog ready to hand to a `MessageProcessor`.')
      ..writeln('///')
      ..writeln(
        '/// A v0.9 surface draws on one catalog, so an agent that also',
      )
      ..writeln('/// uses the basic components needs them in the same one:')
      ..writeln('///')
      ..writeln('/// ```dart')
      ..writeln('/// final catalog = CatalogImplementation(')
      ..writeln('///   id: $aggregateCatalogVariableName.id,')
      ..writeln(
        '///   components: [...BasicComponents.all, '
        '...$aggregateVariableName],',
      )
      ..writeln('///   functions: [')
      ..writeln('///     ...BasicCatalog.v0_9().functions.values,')
      ..writeln('///     ...$aggregateFunctionsVariableName,')
      ..writeln('///   ],')
      ..writeln('///   themeSchema: BasicComponents.api.themeSchema,')
      ..writeln('/// );')
      ..writeln('/// ```')
      ..writeln(
        'final CatalogImplementation $aggregateCatalogVariableName = '
        'CatalogImplementation(',
      )
      ..writeln("  id: '$id',")
      ..writeln('  components: $aggregateVariableName,')
      ..writeln('  functions: $aggregateFunctionsVariableName,')
      ..writeln(');');
    return out.toString();
  }

  /// Writes the right-hand side of a list declaration whose name is already
  /// written, the way `dart format` lays it out once the line is too long,
  /// since the aggregate is not formatted after it is written.
  void _writeList(StringBuffer out, String type, List<_Item> items) {
    if (items.isEmpty) {
      out.writeln('    <$type>[];');
      return;
    }
    out.writeln('    <$type>[');
    for (final item in items) {
      out.writeln('      ${item.variableName},');
    }
    out.writeln('    ];');
  }

  /// Rejects an id that would not survive being written into a string.
  void _checkCatalogId(String id) {
    if (_catalogIdPattern.hasMatch(id)) return;
    throw InvalidGenerationSourceError(
      'The `$catalogIdOption` build option is `$id`, which is not a usable '
      'catalog id. Use reverse-domain notation such as '
      '`com.example.my_catalog`, or the URL the catalog is published at.',
    );
  }

  /// Appends the assembled [Catalog], so that the app has something to hand to
  /// genui rather than a list it still has to wrap by hand.
  void _writeCatalog(StringBuffer out) {
    final id = catalogId;
    if (id != null) _checkCatalogId(id);
    out
      ..writeln()
      ..writeln('/// Every generated [CatalogItem] of this package, as a')
      ..writeln('/// [Catalog] ready to hand to genui.')
      ..writeln('///')
      ..writeln('/// Compose it with any other catalog through')
      ..writeln('/// [Catalog.copyWith], for instance to add genui\'s own')
      ..writeln('/// basic components:')
      ..writeln('///')
      ..writeln('/// ```dart')
      ..writeln('/// final catalog = $aggregateCatalogVariableName.copyWith(')
      ..writeln('///   newItems: BasicCatalogItems.asCatalog().items.toList(),')
      ..writeln(
        '///   newFunctions: BasicCatalogItems.asCatalog().functions'
        '.toList(),',
      )
      ..writeln('/// );')
      ..writeln('/// ```');
    if (id == null) {
      out
        ..writeln('///')
        ..writeln('/// This catalog has no id, because no `$catalogIdOption`')
        ..writeln('/// build option was set. A surface names the catalog it')
        ..writeln('/// was built against, so set one in `build.yaml` before')
        ..writeln('/// talking to an agent:')
        ..writeln('///')
        ..writeln('/// ```yaml')
        ..writeln('/// targets:')
        ..writeln(r'///   $default:')
        ..writeln('///     builders:')
        ..writeln('///       genui_gen_builder:genui_catalog:')
        ..writeln('///         options:')
        ..writeln('///           $catalogIdOption: com.example.my_catalog')
        ..writeln('/// ```');
    }
    out
      ..writeln('final Catalog $aggregateCatalogVariableName = Catalog(')
      ..writeln('  $aggregateVariableName,')
      ..writeln('  functions: $aggregateFunctionsVariableName,');
    if (id != null) out.writeln("  catalogId: '$id',");
    out.writeln(');');
  }
}

/// The names of the generated catalog item variables declared in [source].
///
/// Parsed rather than matched with a regular expression, and parsed
/// syntactically rather than resolved: the file is generated code this package
/// wrote, so its shape is known, and resolving every library of the package to
/// re-derive names the generator already computed would cost a great deal for
/// nothing.
///
/// Selected by the `CatalogItem` suffix rather than by the declared type,
/// which would mean reading `NamedType`. That name has moved inside the
/// analyzer range this package supports — `name2` was introduced, then
/// deprecated in favour of `name`, then removed — while
/// `VariableDeclaration.name` has not. The suffix is this package's own
/// contract (`WidgetSpec.variableName`), already relied on to detect
/// collisions, so nothing new is being trusted here. A `@GenUiData` class
/// generates `<name>GenUiSchema` and `<name>FromGenUiJson`, so neither can be
/// picked up by mistake.
Iterable<String> _catalogItemNames(String source) sync* {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  for (final declaration in unit.declarations) {
    if (declaration is! TopLevelVariableDeclaration) continue;
    for (final variable in declaration.variables.variables) {
      final name = variable.name.lexeme;
      if (name.endsWith('CatalogItem')) yield name;
    }
  }
}

/// Exposed for the generator's own diagnostics.
String catalogItemVariableName(String className) =>
    '${lowerCamel(className)}CatalogItem';

/// The names of the generated catalog function variables declared in [source].
///
/// Selected by the `GenUiFunction` suffix, for the same reasons the items are
/// selected by `CatalogItem`: it is this package's own contract
/// ([FunctionSpec.variableName]), and reading the declared type would mean
/// touching `NamedType`, whose accessor has moved twice inside the analyzer
/// range this package supports. A `@GenUiData` class generates
/// `<name>GenUiSchema`, so it cannot be picked up by mistake.
Iterable<String> _catalogFunctionNames(String source) sync* {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  for (final declaration in unit.declarations) {
    if (declaration is! TopLevelVariableDeclaration) continue;
    for (final variable in declaration.variables.variables) {
      final name = variable.name.lexeme;
      if (name.endsWith('GenUiFunction')) yield name;
    }
  }
}

/// The renderer the generated part [source] was written for, or `null` when
/// it declares no component and no function.
///
/// Read off the declared type of the generated variables, which this package
/// writes itself: a genui part declares `CatalogItem`s and `ClientFunction`s,
/// an a2ui_flutter part `ComponentImplementation`s and
/// `FunctionImplementation`s. The type is read as source text rather than
/// through `NamedType`, for the reason given on [_catalogItemNames].
Renderer? _rendererOf(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  for (final declaration in unit.declarations) {
    if (declaration is! TopLevelVariableDeclaration) continue;
    switch (declaration.variables.type?.toSource()) {
      case 'CatalogItem' || 'ClientFunction':
        return Renderer.genui;
      case 'ComponentImplementation' || 'FunctionImplementation':
        return Renderer.a2uiFlutter;
    }
  }
  return null;
}
