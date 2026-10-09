import 'package:flutter/material.dart';

enum SnapshotArea { wholeMap, visible }

typedef SnapshotOptions = ({SnapshotArea area, bool skipHidden});

/// Asks what to save as an image. [filterActive] offers leaving out markers
/// the legend filter hides. Returns null when cancelled.
Future<SnapshotOptions?> showSnapshotOptionsDialog(
  BuildContext context, {
  required bool filterActive,
}) => showDialog<SnapshotOptions>(
  context: context,
  builder: (_) => _SnapshotOptionsDialog(filterActive: filterActive),
);

class _SnapshotOptionsDialog extends StatefulWidget {
  const _SnapshotOptionsDialog({required this.filterActive});

  final bool filterActive;

  @override
  State<_SnapshotOptionsDialog> createState() => _SnapshotOptionsDialogState();
}

class _SnapshotOptionsDialogState extends State<_SnapshotOptionsDialog> {
  var _area = SnapshotArea.wholeMap;
  var _skipHidden = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zapisz jako obraz'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<SnapshotArea>(
            groupValue: _area,
            onChanged: (area) => setState(() => _area = area!),
            child: const Column(
              children: [
                RadioListTile(
                  value: SnapshotArea.wholeMap,
                  title: Text('Cała mapa'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile(
                  value: SnapshotArea.visible,
                  title: Text('Widoczny fragment'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (widget.filterActive)
            CheckboxListTile(
              value: _skipHidden,
              onChanged: (v) => setState(() => _skipHidden = v!),
              title: const Text('Pomiń znaczniki ukryte filtrem'),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((area: _area, skipHidden: widget.filterActive && _skipHidden)),
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
