import 'package:flutter/material.dart';

import '../../core/plural.dart';
import '../../data/map_shape.dart';

enum ShapeAction { edit, editPoints, delete }

/// Shows a route's or area's details with its actions.
/// Returns the chosen action, or null when dismissed.
Future<ShapeAction?> showShapeDetails(
  BuildContext context,
  MapShape shape, {
  String? colorName,
}) => showModalBottomSheet<ShapeAction>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final theme = Theme.of(context);
    final isRoute = shape.kind == ShapeKind.route;
    final points = shape.points.length;
    final subtitle = [
      isRoute ? 'Trasa' : 'Obszar',
      '$points ${pluralPl(points, 'punkt', 'punkty', 'punktów')}',
      ?colorName,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRoute ? Icons.timeline : Icons.pentagon_outlined,
                color: Color(shape.colorValue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shape.name ??
                      (isRoute ? 'Trasa bez nazwy' : 'Obszar bez nazwy'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              subtitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (shape.style.description case final description?) ...[
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(ShapeAction.delete),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Usuń'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(ShapeAction.editPoints),
                icon: const Icon(Icons.polyline_outlined),
                label: const Text('Zmień punkty'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(ShapeAction.edit),
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
