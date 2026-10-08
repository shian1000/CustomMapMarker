import 'package:flutter/material.dart';

import '../../data/map_project.dart';

/// Asks for a new map name. Returns null when cancelled.
Future<String?> showRenameMapDialog(BuildContext context, String currentName) =>
    _showMapNameDialog(
      context,
      title: 'Zmień nazwę',
      initialName: currentName,
      confirmLabel: 'Zapisz',
    );

/// Asks how to name a map being imported. Returns null when cancelled.
Future<String?> showNewMapNameDialog(
  BuildContext context,
  String suggestedName,
) => _showMapNameDialog(
  context,
  title: 'Nowa mapa',
  initialName: suggestedName,
  confirmLabel: 'Importuj',
);

Future<String?> _showMapNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required String confirmLabel,
}) => showDialog<String>(
  context: context,
  builder: (_) => _MapNameDialog(
    title: title,
    initialName: initialName,
    confirmLabel: confirmLabel,
  ),
);

/// Asks to confirm deleting [summary]. Returns true when confirmed.
Future<bool> showDeleteMapDialog(
  BuildContext context,
  MapSummary summary,
) async {
  final count = summary.markerCount;
  // Instrumental case after "razem z": znacznikiem / znacznikami.
  final markers = switch (count) {
    0 => '',
    1 => ' razem z 1 znacznikiem',
    _ => ' razem z $count znacznikami',
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Usunąć mapę?'),
      content: Text(
        'Mapa „${summary.map.name}” zostanie usunięta$markers. '
        'Tej operacji nie można cofnąć.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Usuń'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _MapNameDialog extends StatefulWidget {
  const _MapNameDialog({
    required this.title,
    required this.initialName,
    required this.confirmLabel,
  });

  final String title;
  final String initialName;
  final String confirmLabel;

  @override
  State<_MapNameDialog> createState() => _MapNameDialogState();
}

class _MapNameDialogState extends State<_MapNameDialog> {
  static const _maxLength = 60;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialName.length,
    );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: _maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nazwa mapy'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Podaj nazwę' : null,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
