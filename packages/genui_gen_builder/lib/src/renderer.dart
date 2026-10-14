/// Which renderer the generated code is written for.
library;

import 'package:source_gen/source_gen.dart';

/// The Flutter renderer a generated part targets.
///
/// genui_gen started on genui, which is being redesigned as a2ui_flutter. The
/// annotations are the same on both, so the builder reads which one the
/// annotations came from rather than asking the app to say it again.
enum Renderer {
  /// genui: a `CatalogItem` whose builder binds the raw JSON itself, and a
  /// `ClientFunction` that answers with a `Stream`.
  genui,

  /// a2ui_flutter: a `ComponentImplementation` whose properties a2ui_core has
  /// already resolved against its schema, and a `FunctionImplementation`.
  a2uiFlutter,
}

/// The name a `package:genui_gen` built on a2ui_flutter declares next to its
/// annotations.
///
/// Its presence, not its value, is what [rendererOf] reads: a genui_gen built
/// on genui has never declared it.
const a2uiFlutterMarker = 'genUiGenTargetsA2uiFlutter';

/// The renderer of the `package:genui_gen` that declares [annotation].
///
/// Read from the annotation rather than from the annotated library's imports,
/// so it is the version of the package the app resolved that decides, whatever
/// the app happens to import or re-export.
Renderer rendererOf(ConstantReader annotation) {
  final library = annotation.objectValue.type?.element?.library;
  if (library == null) return Renderer.genui;
  final marker = library.firstFragment.scope.lookup(a2uiFlutterMarker);
  return marker.getter == null ? Renderer.genui : Renderer.a2uiFlutter;
}
