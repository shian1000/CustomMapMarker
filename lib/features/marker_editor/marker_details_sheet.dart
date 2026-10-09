import 'package:flutter/material.dart';

import '../../data/map_marker.dart';
import '../../shared/marker_icons.dart';
import '../../shared/widgets/marker_pin.dart';

enum MarkerAction { edit, move, delete }

/// Shows a marker's details with its actions.
/// Returns the chosen action, or null when dismissed.
///
/// [colorName] is the legend name of the marker's color, if it has one.
Future<MarkerAction?> showMarkerDetails(
  BuildContext context,
  MapMarker marker, {
  String? colorName,
}) => showModalBottomSheet<MarkerAction>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PinGlyph(
                color: Color(marker.colorValue),
                icon: markerIconFor(marker.icon)?.icon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(marker.label, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          if (colorName != null)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                colorName,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (marker.description case final description?) ...[
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(MarkerAction.delete),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Usuń'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(MarkerAction.move),
                icon: const Icon(Icons.open_with),
                label: const Text('Przesuń'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(MarkerAction.edit),
                icon: const Icon(Icons.edit),
                label: const Text('Edytuj'),
              ),
            ],
          ),
        ],
      ),
    );
  },
);
