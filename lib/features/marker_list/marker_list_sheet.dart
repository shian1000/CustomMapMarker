import 'package:flutter/material.dart';

import '../../core/plural.dart';
import '../../core/text_search.dart';
import '../../data/map_marker.dart';

enum MarkerSort { alphabetical, newest }

/// Shows the markers of a map with search and sorting.
/// Returns the marker the user picked, or null when dismissed.
///
/// [hiddenByFilter] is how many more markers the legend filter hides.
Future<MapMarker?> showMarkerList(
  BuildContext context,
  List<MapMarker> markers, {
  int hiddenByFilter = 0,
}) => showModalBottomSheet<MapMarker>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      MarkerListSheet(markers: markers, hiddenByFilter: hiddenByFilter),
);

class MarkerListSheet extends StatefulWidget {
  const MarkerListSheet({
    super.key,
    required this.markers,
    this.hiddenByFilter = 0,
  });

  final List<MapMarker> markers;
  final int hiddenByFilter;

  @override
  State<MarkerListSheet> createState() => _MarkerListSheetState();
}

class _MarkerListSheetState extends State<MarkerListSheet> {
  final _query = TextEditingController();
  var _sort = MarkerSort.alphabetical;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<MapMarker> get _visible {
    final found = [
      for (final m in widget.markers)
        if (matchesSearch(_query.text, [m.label, m.description])) m,
    ];
    switch (_sort) {
      case MarkerSort.alphabetical:
        found.sort((a, b) {
          final folded = foldForSearch(a.label)
              .compareTo(foldForSearch(b.label));
          return folded != 0 ? folded : a.label.compareTo(b.label);
        });
      case MarkerSort.newest:
        found.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

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
                hintText: 'Szukaj znaczników',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      '${visible.length} z ${widget.markers.length}',
                      if (widget.hiddenByFilter > 0)
                        '${widget.hiddenByFilter} '
                            '${pluralPl(widget.hiddenByFilter, 'ukryty', 'ukryte', 'ukrytych')} '
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
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      switch ((widget.markers.isEmpty, widget.hiddenByFilter)) {
                        (true, 0) =>
                          'Na tej mapie nie ma jeszcze znaczników.\n'
                              'Przytrzymaj palec na mapie, aby dodać.',
                        (true, _) =>
                          'Wszystkie znaczniki są ukryte filtrem.\n'
                              'Zmienisz to w legendzie.',
                        _ => 'Nic nie znaleziono',
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final marker = visible[i];
                      final description = marker.description;
                      return ListTile(
                        key: ValueKey(marker.id),
                        leading: Icon(
                          Icons.location_on,
                          color: Color(marker.colorValue),
                        ),
                        title: Text(marker.label),
                        subtitle: description == null
                            ? null
                            : Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => Navigator.of(context).pop(marker),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
