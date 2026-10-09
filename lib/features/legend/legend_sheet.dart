import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plural.dart';
import '../../data/legend.dart';
import '../../data/map_shape.dart';
import '../../data/providers.dart';
import '../../shared/marker_colors.dart';

/// Shows the legend of map [mapId]: every color with its name, marker count
/// and a switch to show or hide its markers. Changes apply immediately.
Future<void> showLegendSheet(BuildContext context, String mapId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => LegendSheet(mapId: mapId),
    );

/// Asks for a color's name. Returns null when cancelled and '' to clear it.
Future<String?> showColorNameDialog(
  BuildContext context, {
  required Color color,
  String? currentName,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ColorNameDialog(color: color, currentName: currentName),
);

class LegendSheet extends ConsumerWidget {
  const LegendSheet({super.key, required this.mapId});

  final String mapId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final legend = ref.watch(legendProvider(mapId)).value ?? const {};
    final markers = ref.watch(markersProvider(mapId)).value ?? const [];
    final shapes = ref.watch(shapesProvider(mapId)).value ?? const [];
    final repo = ref.read(legendRepositoryProvider);

    // Per color: markers, routes and areas using it.
    final counts = <int, (int, int, int)>{};
    void count(int color, {int m = 0, int r = 0, int a = 0}) {
      final (cm, cr, ca) = counts[color] ?? (0, 0, 0);
      counts[color] = (cm + m, cr + r, ca + a);
    }

    for (final m in markers) {
      count(m.colorValue, m: 1);
    }
    for (final s in shapes) {
      s.kind == ShapeKind.route
          ? count(s.colorValue, r: 1)
          : count(s.colorValue, a: 1);
    }
    // Palette order first, then any other colors markers happen to use.
    final colors = [
      for (final c in markerColors) c.toARGB32(),
      for (final c in counts.keys)
        if (!markerColors.any((p) => p.toARGB32() == c)) c,
    ];
    final usedColors = counts.keys.toList();

    Future<void> rename(int colorValue) async {
      final name = await showColorNameDialog(
        context,
        color: Color(colorValue),
        currentName: legend.nameOf(colorValue),
      );
      if (name != null) await repo.setName(mapId, colorValue, name);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Legenda', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: usedColors.isEmpty
                      ? null
                      : () => repo.setAllHidden(mapId, usedColors, false),
                  child: const Text('Wszystkie'),
                ),
                TextButton(
                  onPressed: usedColors.isEmpty
                      ? null
                      : () => repo.setAllHidden(mapId, usedColors, true),
                  child: const Text('Żadne'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Stuknij kolor, aby nadać mu nazwę. Przełącznikiem pokażesz '
              'lub ukryjesz wszystko w tym kolorze.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: colors.length,
              itemBuilder: (context, i) {
                final colorValue = colors[i];
                final (markerCount, routeCount, areaCount) =
                    counts[colorValue] ?? (0, 0, 0);
                final used = markerCount + routeCount + areaCount > 0;
                final name = legend.nameOf(colorValue);
                return ListTile(
                  key: ValueKey(colorValue),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(colorValue),
                  ),
                  title: Text(
                    name ?? 'Bez nazwy',
                    style: name == null
                        ? TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    used
                        ? [
                            if (markerCount > 0) markerCountLabel(markerCount),
                            if (routeCount > 0) routeCountLabel(routeCount),
                            if (areaCount > 0) areaCountLabel(areaCount),
                          ].join(' · ')
                        : 'Nieużywany',
                  ),
                  trailing: Switch(
                    value: !legend.isHidden(colorValue),
                    // Nothing to show or hide for unused colors.
                    onChanged: !used
                        ? null
                        : (visible) =>
                              repo.setHidden(mapId, colorValue, !visible),
                  ),
                  onTap: () => rename(colorValue),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorNameDialog extends StatefulWidget {
  const _ColorNameDialog({required this.color, this.currentName});

  final Color color;
  final String? currentName;

  @override
  State<_ColorNameDialog> createState() => _ColorNameDialogState();
}

class _ColorNameDialogState extends State<_ColorNameDialog> {
  static const _maxLength = 30;

  late final _name = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: widget.color),
          const SizedBox(width: 12),
          const Flexible(child: Text('Nazwa koloru')),
        ],
      ),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: _maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'np. Zamki, Lasy, Karczmy',
          helperText: 'Zostaw puste, aby usunąć nazwę',
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }
}
