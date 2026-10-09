import 'package:flutter/material.dart';

import '../marker_colors.dart';

/// "Kolor" heading with the legend name of the selected color, and the
/// palette to pick from. Shared by the marker and shape editors.
class ColorPalettePicker extends StatelessWidget {
  const ColorPalettePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.colorNames = const {},
  });

  /// ARGB value of the selected color.
  final int selected;
  final ValueChanged<int> onChanged;

  /// Legend names of colors on the current map.
  final Map<int, String> colorNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Kolor', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                colorNames[selected] ?? 'bez nazwy',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in markerColors)
              _ColorSwatch(
                color: color,
                selected: color.toARGB32() == selected,
                onTap: () => onChanged(color.toARGB32()),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Kolor',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black12,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, color: onColor(color), size: 20)
              : null,
        ),
      ),
    );
  }
}
