/// Recording and replaying agent sessions.
///
/// A generative interface has a problem an ordinary app does not: the screen
/// that failed is not in the source. A model composed it, once, from a context
/// that will not come back. When someone reports that "the confirm button did
/// nothing", there is no screen to open and no state to inspect.
///
/// A trace is that session, kept: every message the agent sent, the contents
/// of each surface's data model whenever they changed, and every action the
/// app sent back. Because A2UI describes interfaces as data rather than code,
/// replaying a trace is deterministic — the same messages build the same
/// surfaces, with no model and no network.
///
/// Record:
///
/// ```dart
/// final recorder = GenUiTraceRecorder.attach(
///   controller,
///   catalogId: catalog.catalogId,
///   redact: const ['/user/email'],
/// );
///
/// transport.messages.listen(recorder.handleMessage);
/// ...
/// await File('bug-4821.a2ui-trace').writeAsString(recorder.build().encode());
/// ```
///
/// Replay, in a test or on a debug screen:
///
/// ```dart
/// final trace = GenUiTrace.decode(await File('bug-4821.a2ui-trace').readAsString());
/// final player = GenUiTracePlayer(trace, catalog: genUiCatalog)..seek(7);
///
/// await tester.pumpWidget(MaterialApp(home: GenUiTraceView(player: player)));
/// expect(find.text('Confirm'), findsOneWidget);
/// ```
///
/// Replaying against the app's current catalog is the useful default: an old
/// session rendered by today's components is how a catalog change that breaks
/// a real conversation shows up before a user finds it.
///
/// Two things worth setting up on the first day rather than the worst day.
/// Name the data model paths that hold personal information in [redact], since
/// a recording keeps what the user typed. And keep anything a component reads
/// from outside the data model — a clock, a random number, a request — behind
/// a function the catalog declares, or the replay will diverge from the
/// session in exactly the places that are hardest to notice.
library;

export 'src/tracing/player.dart';
export 'src/tracing/recorder.dart';
export 'src/tracing/trace.dart';
