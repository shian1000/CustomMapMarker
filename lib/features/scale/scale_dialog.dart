import 'package:flutter/material.dart';

import '../../core/measure.dart';

/// Asks how far apart, in reality, the two points just marked are.
/// Returns the distance in meters, or null when cancelled.
Future<double?> showScaleDialog(BuildContext context) =>
    showDialog<double>(context: context, builder: (_) => const _ScaleDialog());

class _ScaleDialog extends StatefulWidget {
  const _ScaleDialog();

  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _distance = TextEditingController();
  var _unit = DistanceUnit.kilometers;

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  /// Accepts "12,5" as well as "12.5".
  static double? _parse(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_parse(_distance.text)! * _unit.inMeters);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Skala mapy'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Jaka jest prawdziwa odległość między wskazanymi punktami?',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _distance,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Odległość',
                suffixText: _unit.symbol,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final value = _parse(v);
                return value == null || value <= 0
                    ? 'Podaj liczbę większą od zera'
                    : null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<DistanceUnit>(
              showSelectedIcon: false,
              segments: [
                for (final unit in DistanceUnit.values)
                  ButtonSegment(value: unit, label: Text(unit.symbol)),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.single),
            ),
          ],
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
