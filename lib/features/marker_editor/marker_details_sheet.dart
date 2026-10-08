import 'package:flutter/material.dart';

import '../../data/map_marker.dart';

enum MarkerAction { edit, move, delete }

/// Shows a marker's details with its actions.
/// Returns the chosen action, or null when dismissed.
Future<MarkerAction?> showMarkerDetails(
  BuildContext context,
  MapMarker marker,
) => showModalBottomSheet<MarkerAction>(
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
              Icon(Icons.location_on, color: Color(marker.colorValue)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(marker.label, style: theme.textTheme.titleLarge),
              ),
            ],
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
