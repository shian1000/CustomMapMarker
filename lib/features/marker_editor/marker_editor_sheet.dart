import 'package:flutter/material.dart';

import '../../data/map_marker.dart';
import '../../shared/marker_colors.dart';
import '../../shared/marker_icons.dart';
import '../../shared/widgets/color_palette_picker.dart';

/// Shows a bottom sheet for creating or editing a marker.
/// Returns null when dismissed without saving.
///
/// [colorNames] are the map's legend names, shown for the selected color.
Future<MarkerDraft?> showMarkerEditor(
  BuildContext context, {
  MarkerDraft? initial,
  Map<int, String> colorNames = const {},
}) => showModalBottomSheet<MarkerDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => MarkerEditorSheet(initial: initial, colorNames: colorNames),
);

class MarkerEditorSheet extends StatefulWidget {
  const MarkerEditorSheet({
    super.key,
    this.initial,
    this.colorNames = const {},
  });

  final MarkerDraft? initial;
  final Map<int, String> colorNames;

  @override
  State<MarkerEditorSheet> createState() => _MarkerEditorSheetState();
}

class _MarkerEditorSheetState extends State<MarkerEditorSheet> {
  static const _maxLabelLength = 40;

  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.initial?.label);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late int _colorValue =
      widget.initial?.colorValue ?? markerColors.first.toARGB32();
  late String? _icon = markerIconFor(widget.initial?.icon)?.key;

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    _label.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final description = _description.text.trim();
    Navigator.of(context).pop(
      MarkerDraft(
        label: _label.text.trim(),
        description: description.isEmpty ? null : description,
        colorValue: _colorValue,
        icon: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        // Scrolls when the keyboard leaves too little room for everything.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isNew ? 'Nowy znacznik' : 'Edytuj znacznik',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _label,
                autofocus: _isNew,
                maxLength: _maxLabelLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nazwa',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Podaj nazwę' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Opis (opcjonalnie)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ColorPalettePicker(
                selected: _colorValue,
                colorNames: widget.colorNames,
                onChanged: (c) => setState(() => _colorValue = c),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Ikona', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      markerIconFor(_icon)?.label ?? 'zwykła pinezka',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  _IconChoice(
                    icon: Icons.location_on,
                    label: 'Zwykła pinezka',
                    color: Color(_colorValue),
                    selected: _icon == null,
                    onTap: () => setState(() => _icon = null),
                  ),
                  for (final choice in markerIcons)
                    _IconChoice(
                      icon: choice.icon,
                      label: choice.label,
                      color: Color(_colorValue),
                      selected: choice.key == _icon,
                      onTap: () => setState(() => _icon = choice.key),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(_isNew ? 'Dodaj' : 'Zapisz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// The marker's color, used to preview the selected icon.
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? color : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? onColor(color) : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
