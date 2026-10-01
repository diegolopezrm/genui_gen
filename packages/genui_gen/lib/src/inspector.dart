import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:genui/genui.dart';

import 'semantics.dart';
import 'surface_graph.dart';
import 'tracing/recorder.dart';
import 'tracing/trace.dart';

/// A debug panel over a running generative interface.
///
/// Wrap it around whatever renders the surfaces and it draws a handle in the
/// corner. Open it and you see, while you use the app: the component tree the
/// model built, every data model path and what reads it, what a screen reader
/// would announce, and the messages that got the screen into this state.
///
/// ```dart
/// GenUiInspector(
///   controller: controller,
///   recorder: recorder,
///   child: GenUiConversation(...),
/// )
/// ```
///
/// It is compiled out of a release build by default: [enabled] defaults to
/// [kDebugMode], and when it is false the [child] is returned untouched.
///
/// The panel excludes itself from semantics, so what the Semantics tab reports
/// is the app's own tree and nothing a screen reader hears comes from the
/// inspector.
class GenUiInspector extends StatefulWidget {
  /// Creates an inspector over [child].
  const GenUiInspector({
    super.key,
    required this.controller,
    required this.child,
    this.recorder,
    this.enabled = kDebugMode,
    this.open = false,
  });

  /// The controller whose surfaces the panel reports on.
  final SurfaceController controller;

  /// The app, rendered under the panel.
  final Widget child;

  /// A recorder on the same controller, for the Messages tab.
  ///
  /// Without one the panel shows the surfaces as they are now, which is most
  /// of the story but not how they got there.
  final GenUiTraceRecorder? recorder;

  /// Whether to show the panel at all.
  final bool enabled;

  /// Whether the panel starts open.
  final bool open;

  @override
  State<GenUiInspector> createState() => _GenUiInspectorState();
}

enum _Tab { tree, data, semantics, messages }

const Color _ink = Color(0xFFE6E8EB);
const Color _dim = Color(0xFF9BA3AD);
const Color _panelColor = Color(0xFF1C2026);
const Color _lineColor = Color(0xFF2E343D);
const Color _accent = Color(0xFFE0B457);
const Color _alarm = Color(0xFFE88A7D);
const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: <String>['Menlo', 'Consolas'],
  fontSize: 11.5,
  height: 1.45,
  color: _ink,
);

class _GenUiInspectorState extends State<GenUiInspector> {
  StreamSubscription<SurfaceUpdate>? _updates;
  final Map<String, SurfaceDefinition> _definitions =
      <String, SurfaceDefinition>{};
  final Map<String, Object?> _data = <String, Object?>{};
  final Map<String, VoidCallback> _dataListeners = <String, VoidCallback>{};

  String? _surfaceId;
  _Tab _tab = _Tab.tree;
  bool _open = false;
  double _height = 320;
  String? _expanded;

  SemanticsHandle? _semanticsHandle;
  List<GenUiSemanticNode> _semantics = const <GenUiSemanticNode>[];

  GenUiTrace? _trace;

  @override
  void initState() {
    super.initState();
    _open = widget.open;
    if (widget.enabled) _attach();
  }

  @override
  void didUpdateWidget(GenUiInspector old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller || old.enabled != widget.enabled) {
      _detach();
      if (widget.enabled) _attach();
    }
    if (old.recorder != widget.recorder) {
      old.recorder?.changes.removeListener(_onTrace);
      widget.recorder?.changes.addListener(_onTrace);
      _onTrace();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    _updates = widget.controller.surfaceUpdates.listen(_onSurfaceUpdate);
    widget.recorder?.changes.addListener(_onTrace);
    _onTrace();
  }

  void _detach() {
    _updates?.cancel();
    _updates = null;
    widget.recorder?.changes.removeListener(_onTrace);
    for (final MapEntry<String, VoidCallback> entry in _dataListeners.entries) {
      _rootOf(entry.key)?.removeListener(entry.value);
    }
    _dataListeners.clear();
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
  }

  void _onSurfaceUpdate(SurfaceUpdate update) {
    switch (update) {
      case SurfaceAdded(:final definition) ||
          ComponentsUpdated(:final definition):
        _definitions[definition.surfaceId] = definition;
        _watchData(definition.surfaceId);
      case SurfaceRemoved(:final surfaceId):
        _definitions.remove(surfaceId);
        _data.remove(surfaceId);
        final VoidCallback? listener = _dataListeners.remove(surfaceId);
        if (listener != null) _rootOf(surfaceId)?.removeListener(listener);
    }
    _surfaceId ??= _definitions.keys.firstOrNull;
    if (!_definitions.containsKey(_surfaceId)) {
      _surfaceId = _definitions.keys.firstOrNull;
    }
    if (mounted) setState(() {});
  }

  /// The data model root of [surfaceId], or `null` when the surface is gone.
  ///
  /// `contextFor` throws once a surface has been removed, and a removal and a
  /// rebuild of the panel can land in either order.
  ValueListenable<Object?>? _rootOf(String surfaceId) {
    try {
      return widget.controller
          .contextFor(surfaceId)
          .dataModel
          .subscribe<Object?>(DataPath(''));
    } on StateError {
      return null;
    }
  }

  void _watchData(String surfaceId) {
    if (_dataListeners.containsKey(surfaceId)) return;
    final ValueListenable<Object?>? root = _rootOf(surfaceId);
    if (root == null) return;
    void listener() {
      _data[surfaceId] = root.value;
      if (mounted) setState(() {});
    }

    root.addListener(listener);
    _dataListeners[surfaceId] = listener;
    _data[surfaceId] = root.value;
  }

  void _onTrace() {
    final GenUiTrace? trace = widget.recorder?.build();
    if (!mounted) {
      _trace = trace;
      return;
    }
    setState(() => _trace = trace);
  }

  /// Takes the app's semantics tree, turning semantics on if they were off.
  ///
  /// Switching them on is what asks for the tree to be built, and the build
  /// happens in a later frame, so a first read can land before there is
  /// anything to read. [attempts] is how many frames to give it.
  void _readSemantics({int attempts = 3}) {
    _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      List<GenUiSemanticNode> nodes;
      try {
        nodes = genUiRenderedSemantics();
      } on StateError {
        nodes = const <GenUiSemanticNode>[];
      }
      if (nodes.isEmpty && attempts > 1) {
        WidgetsBinding.instance.ensureVisualUpdate();
        _readSemantics(attempts: attempts - 1);
        return;
      }
      setState(() => _semantics = nodes);
    });
  }

  void _select(_Tab tab) {
    setState(() {
      _tab = tab;
      _expanded = null;
    });
    if (tab == _Tab.semantics) _readSemantics();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: widget.child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // The panel is a tool, not part of the interface under test: keeping
          // it out of the semantics tree is what makes the Semantics tab
          // report the app rather than itself.
          child: ExcludeSemantics(
            child: SafeArea(top: false, child: _open ? _panel() : _handle()),
          ),
        ),
      ],
    );
  }

  // Bottom left, because bottom right is where an app puts the control the
  // user is most likely to want while the panel is shut.
  Widget _handle() => Align(
    alignment: Alignment.bottomLeft,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: _panelColor,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _open = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              'genui ${_definitions.length}',
              style: _mono.copyWith(color: _accent),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _panel() => Material(
    color: _panelColor,
    child: SizedBox(
      height: _height,
      child: Column(
        children: <Widget>[
          _grip(),
          _header(),
          const Divider(height: 1, color: _lineColor),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _grip() => GestureDetector(
    onVerticalDragUpdate: (DragUpdateDetails details) => setState(() {
      _height = (_height - details.delta.dy).clamp(
        140.0,
        MediaQuery.sizeOf(context).height - 80,
      );
    }),
    child: Container(
      height: 14,
      alignment: Alignment.center,
      color: const Color(0x00000000),
      child: Container(
        width: 36,
        height: 3,
        decoration: const BoxDecoration(
          color: _lineColor,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );

  Widget _header() {
    final List<_Tab> tabs = <_Tab>[
      _Tab.tree,
      _Tab.data,
      _Tab.semantics,
      if (widget.recorder != null) _Tab.messages,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
      child: Row(
        children: <Widget>[
          for (final _Tab tab in tabs)
            _TabButton(
              label: tab.name,
              selected: _tab == tab,
              onTap: () => _select(tab),
            ),
          const Spacer(),
          if (_definitions.length > 1) _surfacePicker(),
          if (_tab == _Tab.semantics)
            _IconText(label: 'reload', onTap: _readSemantics),
          _IconText(label: 'close', onTap: () => setState(() => _open = false)),
        ],
      ),
    );
  }

  Widget _surfacePicker() => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: DropdownButton<String>(
      value: _surfaceId,
      isDense: true,
      dropdownColor: const Color(0xFF1C2026),
      underline: const SizedBox.shrink(),
      style: _mono.copyWith(color: _dim),
      items: <DropdownMenuItem<String>>[
        for (final String id in _definitions.keys)
          DropdownMenuItem<String>(value: id, child: Text(id)),
      ],
      onChanged: (String? id) => setState(() {
        _surfaceId = id;
        _expanded = null;
      }),
    ),
  );

  Widget _body() {
    if (_tab == _Tab.messages) return _messages();
    if (_tab == _Tab.semantics) return _semanticsList();

    final SurfaceDefinition? definition = _definitions[_surfaceId];
    if (definition == null) {
      return _empty('No surface yet. It appears here as soon as one arrives.');
    }
    final GenUiSurfaceGraph graph = GenUiSurfaceGraph.of(definition);
    return _tab == _Tab.tree ? _tree(graph) : _dataList(graph);
  }

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(message, style: _mono.copyWith(color: _dim)),
  );

  Widget _tree(GenUiSurfaceGraph graph) {
    final List<String> ids = <String>[
      ...graph.order,
      ...graph.unreachable.toList()..sort(),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: <Widget>[
        _notes(graph.describe()),
        for (final String id in ids)
          _ComponentRow(
            id: id,
            component: graph.definition.components[id]!,
            depth: graph.depthOf(id) ?? 0,
            reached: !graph.unreachable.contains(id),
            cyclic: graph.cyclic.contains(id),
            paths: graph.pathsOf(id),
            expanded: _expanded == id,
            onTap: () =>
                setState(() => _expanded = _expanded == id ? null : id),
          ),
      ],
    );
  }

  Widget _dataList(GenUiSurfaceGraph graph) {
    final _Entries entries = _entriesOf(_data[graph.definition.surfaceId]);

    // A binding resolves to a family of paths when it sits inside a template,
    // so each one is matched against the data rather than looked up.
    final readers = <String, Set<String>>{};
    final missing = <String, Set<String>>{};
    for (final MapEntry<String, Set<String>> binding
        in graph.pathBindings.entries) {
      final List<String> matched = _match(binding.key, entries.values.keys);
      if (matched.isEmpty) {
        missing[binding.key] = binding.value;
        continue;
      }
      for (final String path in matched) {
        readers.putIfAbsent(path, () => <String>{}).addAll(binding.value);
      }
    }

    final List<String> rows = <String>{
      ...entries.leaves,
      ...readers.keys,
    }.toList()..sort();
    if (rows.isEmpty && missing.isEmpty) {
      return _empty('The surface holds no data and binds no paths.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: <Widget>[
        // What a component asked for and the data model never had, first: it
        // is not part of the data model, and it is the finding.
        for (final String path in missing.keys.toList()..sort())
          _PathRow(path: path, value: _absent, readers: missing[path]!),
        for (final String path in rows)
          _PathRow(
            path: path,
            value: entries.values[path],
            readers: readers[path] ?? const <String>{},
          ),
      ],
    );
  }

  Widget _semanticsList() {
    if (_semantics.isEmpty) {
      return _empty(
        'Nothing in the semantics tree. Either the surface announces nothing, '
        'which is itself the finding, or the tree has not been built yet; '
        'reload to take it again.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: <Widget>[
        for (final GenUiSemanticNode node in _semantics)
          _SemanticsRow(node: node),
      ],
    );
  }

  Widget _messages() {
    final GenUiTrace? trace = _trace;
    if (trace == null || trace.steps.isEmpty) {
      return _empty('Nothing recorded yet.');
    }
    final List<GenUiTraceStep> steps = trace.steps.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: steps.length,
      itemBuilder: (BuildContext context, int index) {
        final GenUiTraceStep step = steps[index];
        final String key = 'step${steps.length - index}';
        return _StepRow(
          step: step,
          number: steps.length - index,
          expanded: _expanded == key,
          onTap: () =>
              setState(() => _expanded = _expanded == key ? null : key),
        );
      },
    );
  }

  Widget _notes(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Text(text, style: _mono.copyWith(color: _dim)),
  );
}

/// Stands in for a path a component binds that the data model has no entry
/// for, which `null` cannot: a path holding `null` and a path that was never
/// written are different bugs.
const Object _absent = Object();

/// Every path in a data model, and which of them hold a value rather than
/// more data model.
///
/// Both halves are needed. The leaves are the data model as a person reads it,
/// and the rest are there because a binding can name a list or an object: a
/// template binds the list it repeats over, and reporting that as missing
/// because it is not a leaf would be wrong.
typedef _Entries = ({Map<String, Object?> values, Set<String> leaves});

_Entries _entriesOf(Object? value) {
  final values = <String, Object?>{};
  final leaves = <String>{};
  void walk(String path, Object? node) {
    final String key = path.isEmpty ? '/' : path;
    values[key] = node;
    switch (node) {
      case final Map<Object?, Object?> map when map.isNotEmpty:
        for (final MapEntry<Object?, Object?> entry in map.entries) {
          walk('$path/${entry.key}', entry.value);
        }
      case final List<Object?> list when list.isNotEmpty:
        for (var i = 0; i < list.length; i++) {
          walk('$path/$i', list[i]);
        }
      case _:
        leaves.add(key);
    }
  }

  walk('', value);
  return (values: values, leaves: leaves);
}

/// The paths in [keys] that [pattern] names, expanding template rows.
List<String> _match(String pattern, Iterable<String> keys) {
  if (!pattern.contains('/$genUiRowWildcard')) {
    return keys.contains(pattern) ? <String>[pattern] : const <String>[];
  }
  final String shape = pattern
      .split('/')
      .map(
        (String segment) =>
            segment == genUiRowWildcard ? '[^/]+' : RegExp.escape(segment),
      )
      .join('/');
  final RegExp rows = RegExp('^$shape\$');
  return keys.where(rows.hasMatch).toList();
}

String _short(Object? value) {
  if (value == _absent) return 'not in the data model';
  final String text = switch (value) {
    final String text => '"$text"',
    final List<Object?> list => '${list.length} items',
    final Map<Object?, Object?> map => '${map.length} keys',
    _ => jsonEncode(value),
  };
  return text.length > 60 ? '${text.substring(0, 57)}...' : text;
}

String _pretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: _mono.copyWith(
          color: selected ? _accent : _dim,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: _mono.copyWith(color: _dim)),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.child, this.onTap, this.indent = 0});

  final Widget child;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12 + indent, 5, 12, 5),
      child: child,
    ),
  );
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.id,
    required this.component,
    required this.depth,
    required this.reached,
    required this.cyclic,
    required this.paths,
    required this.expanded,
    required this.onTap,
  });

  final String id;
  final Component component;
  final int depth;
  final bool reached;
  final bool cyclic;
  final Set<String> paths;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<String> sorted = paths.toList()..sort();
    return _Row(
      onTap: onTap,
      indent: reached ? depth * 14 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: _mono,
              children: <InlineSpan>[
                TextSpan(
                  text: component.type,
                  style: const TextStyle(color: _accent),
                ),
                TextSpan(
                  text: '  $id',
                  style: const TextStyle(color: _dim),
                ),
                if (!reached)
                  const TextSpan(
                    text: '  nothing reaches this',
                    style: TextStyle(color: _alarm),
                  ),
                if (cyclic)
                  const TextSpan(
                    text: '  contains itself',
                    style: TextStyle(color: _alarm),
                  ),
              ],
            ),
          ),
          if (sorted.isNotEmpty && !expanded)
            Text(sorted.join('  '), style: _mono.copyWith(color: _dim)),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _pretty(component.properties),
                style: _mono.copyWith(color: _dim),
              ),
            ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.path,
    required this.value,
    required this.readers,
  });

  final String path;
  final Object? value;
  final Set<String> readers;

  @override
  Widget build(BuildContext context) {
    final bool absent = value == _absent;
    final List<String> sorted = readers.toList()..sort();
    return _Row(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: _mono,
              children: <InlineSpan>[
                TextSpan(text: path),
                const TextSpan(text: '  '),
                TextSpan(
                  text: _short(value),
                  style: TextStyle(color: absent ? _alarm : _accent),
                ),
              ],
            ),
          ),
          Text(
            sorted.isEmpty ? 'no component reads it' : sorted.join('  '),
            style: _mono.copyWith(color: sorted.isEmpty ? _alarm : _dim),
          ),
        ],
      ),
    );
  }
}

class _SemanticsRow extends StatelessWidget {
  const _SemanticsRow({required this.node});

  final GenUiSemanticNode node;

  @override
  Widget build(BuildContext context) {
    final List<String> state = <String>[
      for (final MapEntry<String, bool> entry in node.state.entries)
        if (entry.value) entry.key,
    ];
    // The same rule `genUiSemanticsAudit` applies: a control nobody can
    // announce is a finding, and an unnamed region someone scrolls is not.
    final bool unnamed =
        node.name.isEmpty && node.tooltip.isEmpty && node.isOperable;
    return _Row(
      child: Text.rich(
        TextSpan(
          style: _mono,
          children: <InlineSpan>[
            TextSpan(
              text: node.role.padRight(11),
              style: const TextStyle(color: _accent),
            ),
            TextSpan(
              text: unnamed ? 'no name' : node.name,
              style: TextStyle(color: unnamed ? _alarm : _ink),
            ),
            if (node.value.isNotEmpty)
              TextSpan(
                text: '  = ${node.value}',
                style: const TextStyle(color: _dim),
              ),
            if (state.isNotEmpty)
              TextSpan(
                text: '  ${state.join(' ')}',
                style: const TextStyle(color: _dim),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.number,
    required this.expanded,
    required this.onTap,
  });

  final GenUiTraceStep step;
  final int number;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String kind, String summary, Object? detail) = switch (step) {
      GenUiMessageStep(:final message) => (
        'message',
        // Every message carries the protocol version; what it says it is
        // doing is the other key.
        message.keys.where((String key) => key != 'version').join(' '),
        message,
      ),
      GenUiDataStep(:final surfaceId, :final data) => ('data', surfaceId, data),
      GenUiEventStep(:final event) => ('event', _short(event), event),
    };
    return _Row(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: _mono,
              children: <InlineSpan>[
                TextSpan(
                  text: '$number'.padLeft(3),
                  style: const TextStyle(color: _dim),
                ),
                TextSpan(
                  text: '  ${step.at.inMilliseconds}ms',
                  style: const TextStyle(color: _dim),
                ),
                TextSpan(
                  text: '  $kind',
                  style: const TextStyle(color: _accent),
                ),
                TextSpan(text: '  $summary'),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_pretty(detail), style: _mono.copyWith(color: _dim)),
            ),
        ],
      ),
    );
  }
}
