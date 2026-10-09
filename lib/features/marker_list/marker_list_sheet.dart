import 'package:flutter/material.dart';

import '../../core/plural.dart';
import '../../core/text_search.dart';
import '../../data/map_marker.dart';
import '../../data/map_shape.dart';
import '../../shared/marker_icons.dart';
import '../../shared/widgets/marker_pin.dart';

enum MarkerSort { alphabetical, newest }

/// What the user picked in the list.
sealed class MapListPick {
  const MapListPick();
}

class MarkerPick extends MapListPick {
  const MarkerPick(this.marker);
  final MapMarker marker;
}

class ShapePick extends MapListPick {
  const ShapePick(this.shape);
  final MapShape shape;
}

/// How many items of each kind the legend filter hides.
typedef HiddenCounts = ({int markers, int routes, int areas});

const _noneHidden = (markers: 0, routes: 0, areas: 0);

/// Shows the markers, routes and areas of a map in tabs, with one search and
/// sort for all. Returns what the user picked, or null when dismissed.
Future<MapListPick?> showMapList(
  BuildContext context, {
  required List<MapMarker> markers,
  List<MapShape> shapes = const [],
  HiddenCounts hidden = _noneHidden,
  Set<ShapeKind> kindsOff = const {},
}) => showModalBottomSheet<MapListPick>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => MapListSheet(
    markers: markers,
    shapes: shapes,
    hidden: hidden,
    kindsOff: kindsOff,
  ),
);

/// One row of the list, whatever it stands for.
class _Entry {
  _Entry({
    required this.title,
    required this.named,
    required this.subtitle,
    required this.createdAt,
    required this.leading,
    required this.pick,
  });

  final String title;

  /// False for unnamed routes and areas, which sort after named ones.
  final bool named;
  final String? subtitle;
  final DateTime createdAt;
  final Widget leading;
  final MapListPick pick;
}

class MapListSheet extends StatefulWidget {
  const MapListSheet({
    super.key,
    required this.markers,
    this.shapes = const [],
    this.hidden = _noneHidden,
    this.kindsOff = const {},
  });

  final List<MapMarker> markers;
  final List<MapShape> shapes;
  final HiddenCounts hidden;

  /// Kinds turned off in the settings, so not drawn and not listed.
  final Set<ShapeKind> kindsOff;

  @override
  State<MapListSheet> createState() => _MapListSheetState();
}

class _MapListSheetState extends State<MapListSheet>
    with SingleTickerProviderStateMixin {
  final _query = TextEditingController();
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  var _sort = MarkerSort.alphabetical;

  @override
  void dispose() {
    _query.dispose();
    _tabs.dispose();
    super.dispose();
  }

  late final List<_Entry> _markerEntries = [
    for (final m in widget.markers)
      _Entry(
        title: m.label,
        named: true,
        subtitle: m.description,
        createdAt: m.createdAt,
        leading: PinGlyph(
          color: Color(m.colorValue),
          icon: markerIconFor(m.icon)?.icon,
          size: 32,
        ),
        pick: MarkerPick(m),
      ),
  ];

  List<_Entry> _shapeEntries(ShapeKind kind) => [
    for (final s in widget.shapes)
      if (s.kind == kind)
        _Entry(
          title:
              s.name ??
              (kind == ShapeKind.route
                  ? 'Trasa bez nazwy'
                  : 'Obszar bez nazwy'),
          named: s.name != null,
          subtitle: s.style.description,
          createdAt: s.createdAt,
          leading: SizedBox.square(
            dimension: 32,
            child: Icon(
              kind == ShapeKind.route
                  ? Icons.timeline
                  : Icons.pentagon_outlined,
              color: Color(s.colorValue),
            ),
          ),
          pick: ShapePick(s),
        ),
  ];

  late final List<_Entry> _routeEntries = _shapeEntries(ShapeKind.route);
  late final List<_Entry> _areaEntries = _shapeEntries(ShapeKind.area);

  List<_Entry> _found(List<_Entry> entries) {
    final found = [
      for (final e in entries)
        if (matchesSearch(_query.text, [if (e.named) e.title, e.subtitle])) e,
    ];
    switch (_sort) {
      case MarkerSort.alphabetical:
        found.sort((a, b) {
          if (a.named != b.named) return a.named ? -1 : 1;
          final folded = foldForSearch(a.title)
              .compareTo(foldForSearch(b.title));
          return folded != 0 ? folded : a.title.compareTo(b.title);
        });
      case MarkerSort.newest:
        found.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = [_markerEntries, _routeEntries, _areaEntries];
    final found = [for (final entries in all) _found(entries)];
    final hidden = [
      widget.hidden.markers,
      widget.hidden.routes,
      widget.hidden.areas,
    ];
    final tab = _tabs.index;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Szukaj',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_query.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'Znaczniki (${found[0].length})'),
              Tab(text: 'Trasy (${found[1].length})'),
              Tab(text: 'Obszary (${found[2].length})'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      '${found[tab].length} z ${all[tab].length}',
                      if (hidden[tab] > 0)
                        '${hidden[tab]} '
                            '${pluralPl(hidden[tab], 'ukryty', 'ukryte', 'ukrytych')} '
                            'filtrem',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SegmentedButton<MarkerSort>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: MarkerSort.alphabetical,
                      label: Text('A–Z'),
                    ),
                    ButtonSegment(
                      value: MarkerSort.newest,
                      label: Text('Najnowsze'),
                    ),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (s) => setState(() => _sort = s.single),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (var i = 0; i < 3; i++)
                  _EntryList(
                    entries: found[i],
                    controller: i == tab ? scrollController : null,
                    empty: switch ((all[i].isEmpty, hidden[i], i)) {
                      _
                          when i == 1 &&
                              widget.kindsOff.contains(ShapeKind.route) =>
                        'Trasy są wyłączone w ustawieniach.',
                      _
                          when i == 2 &&
                              widget.kindsOff.contains(ShapeKind.area) =>
                        'Obszary są wyłączone w ustawieniach.',
                      (true, 0, 0) =>
                        'Na tej mapie nie ma jeszcze znaczników.\n'
                            'Przytrzymaj palec na mapie, aby dodać.',
                      (true, 0, 1) =>
                        'Na tej mapie nie ma jeszcze tras.\n'
                            'Narysujesz je przyciskiem „Rysuj”.',
                      (true, 0, _) =>
                        'Na tej mapie nie ma jeszcze obszarów.\n'
                            'Narysujesz je przyciskiem „Rysuj”.',
                      (true, _, _) =>
                        'Wszystko jest ukryte filtrem.\n'
                            'Zmienisz to w legendzie.',
                      _ => 'Nic nie znaleziono',
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.controller,
    required this.empty,
  });

  final List<_Entry> entries;
  final ScrollController? controller;

  /// Shown when there are no entries.
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: e.leading,
          title: Text(
            e.title,
            style: e.named
                ? null
                : const TextStyle(fontStyle: FontStyle.italic),
          ),
          subtitle: e.subtitle == null
              ? null
              : Text(e.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).pop(e.pick),
        );
      },
    );
  }
}
