import 'package:flutter/material.dart';

import '../../data/map_project.dart';

/// Asks for a new map name. Returns null when cancelled.
Future<String?> showRenameMapDialog(BuildContext context, String currentName) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameMapDialog(currentName: currentName),
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

class _RenameMapDialog extends StatefulWidget {
  const _RenameMapDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameMapDialog> createState() => _RenameMapDialogState();
}

class _RenameMapDialogState extends State<_RenameMapDialog> {
  static const _maxLength = 60;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.currentName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
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
      title: const Text('Zmień nazwę'),
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
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }
}
