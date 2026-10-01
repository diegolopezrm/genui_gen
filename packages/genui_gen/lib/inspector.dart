/// A debug panel over a running generative interface.
///
/// Debugging an ordinary screen starts by opening the file that built it. A
/// generative one has no such file: a model composed the screen at runtime,
/// from a context that is gone, and the only record of what it decided is a
/// message that was handled and dropped. So the usual first question, "what is
/// this thing made of", has no answer in the source.
///
/// [GenUiInspector] is that answer, on screen while you use the app:
///
/// ```dart
/// GenUiInspector(
///   controller: controller,
///   recorder: recorder,
///   child: GenUiConversation(...),
/// )
/// ```
///
/// Four tabs, each for a question that comes up in practice.
///
/// **Tree** is the component tree the model built, with the data paths each
/// component binds. Three things it flags are bugs rather than information: a
/// child reference naming a component that was never created, a component
/// nothing reaches from the root, and a component that contains itself.
///
/// **Data** is every path, what it holds right now, and which components read
/// it. It reads both ways, which is the point: a path no component reads is
/// payload the agent sent for nothing, and a path a component binds that the
/// data model has no entry for is the usual reason a field renders empty.
///
/// **Semantics** is what a screen reader would announce, taken live. A
/// generated screen can announce nothing at all without looking any different,
/// and this is where that shows.
///
/// **Messages** needs a [GenUiTraceRecorder] and lists the session: what the
/// agent sent, how the data model changed, what the app sent back. The same
/// recorder writes a file you can replay later, from
/// `package:genui_gen/tracing.dart`.
///
/// [GenUiSurfaceGraph] is the part of this with no widgets in it, for a test
/// that wants to assert on the shape of a surface rather than look at it.
///
/// The panel is gone from a release build: `enabled` defaults to `kDebugMode`,
/// and when it is false the child is returned untouched.
library;

export 'src/inspector.dart' show GenUiInspector;
export 'src/surface_graph.dart';
