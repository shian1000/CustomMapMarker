import 'package:flutter/material.dart';

import '../../data/map_shape.dart';
import '../../shared/marker_colors.dart';
import '../../shared/widgets/color_palette_picker.dart';
import '../map_view/shape_layers.dart';

/// Shows a bottom sheet for naming and styling a route or area.
/// Returns null when dismissed without saving.
Future<ShapeStyle?> showShapeEditor(
  BuildContext context, {
  required ShapeKind kind,
  ShapeStyle? initial,
  Map<int, String> colorNames = const {},
}) => showModalBottomSheet<ShapeStyle>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      ShapeEditorSheet(kind: kind, initial: initial, colorNames: colorNames),
);

class ShapeEditorSheet extends StatefulWidget {
  const ShapeEditorSheet({
    super.key,
    required this.kind,
    this.initial,
    this.colorNames = const {},
  });

  final ShapeKind kind;
  final ShapeStyle? initial;
  final Map<int, String> colorNames;

  @override
  State<ShapeEditorSheet> createState() => _ShapeEditorSheetState();
}

class _ShapeEditorSheetState extends State<ShapeEditorSheet> {
  static const _maxNameLength = 40;
  static const _opacities = [0.15, 0.3, 0.45];

  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late int _colorValue =
      widget.initial?.colorValue ?? markerColors.first.toARGB32();
  late ShapeWidth _width = widget.initial?.width ?? ShapeWidth.medium;
  late bool _dashed = widget.initial?.dashed ?? false;
  late double _opacity = widget.initial?.fillOpacity ?? 0.3;

  bool get _isArea => widget.kind == ShapeKind.area;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  ShapeStyle get _style {
    String? text(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return ShapeStyle(
      name: text(_name),
      description: text(_description),
      colorValue: _colorValue,
      width: _width,
      dashed: _dashed,
      fillOpacity: _opacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.initial == null;
    final title = switch ((widget.kind, isNew)) {
      (ShapeKind.route, true) => 'Nowa trasa',
      (ShapeKind.route, false) => 'Edytuj trasę',
      (ShapeKind.area, true) => 'Nowy obszar',
      (ShapeKind.area, false) => 'Edytuj obszar',
    };

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                _StylePreview(kind: widget.kind, style: _style),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: _maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nazwa (opcjonalnie)',
                hintText: _isArea ? 'np. Temeria' : 'np. Szlak do Novigradu',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
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
            label(_isArea ? 'Granica' : 'Linia'),
            SegmentedButton<ShapeWidth>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ShapeWidth.thin, label: Text('Cienka')),
                ButtonSegment(value: ShapeWidth.medium, label: Text('Średnia')),
                ButtonSegment(value: ShapeWidth.thick, label: Text('Gruba')),
              ],
              selected: {_width},
              onSelectionChanged: (s) => setState(() => _width = s.single),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Ciągła')),
                ButtonSegment(value: true, label: Text('Przerywana')),
              ],
              selected: {_dashed},
              onSelectionChanged: (s) => setState(() => _dashed = s.single),
            ),
            if (_isArea) ...[
              label('Wypełnienie'),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final o in _opacities)
                    ButtonSegment(
                      value: o,
                      label: Text('${(o * 100).round()}%'),
                    ),
                ],
                selected: {_opacity},
                onSelectionChanged: (s) => setState(() => _opacity = s.single),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_style),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small sample of the line or area as it will look on the map.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.kind, required this.style});

  final ShapeKind kind;
  final ShapeStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 40,
      child: CustomPaint(painter: _PreviewPainter(kind, style)),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.kind, this.style);

  final ShapeKind kind;
  final ShapeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final color = Color(style.colorValue);
    final width = strokeWidthOf(style.width);
    final path = Path();
    if (kind == ShapeKind.area) {
      path
        ..moveTo(size.width * 0.1, size.height * 0.8)
        ..lineTo(size.width * 0.35, size.height * 0.15)
        ..lineTo(size.width * 0.9, size.height * 0.3)
        ..lineTo(size.width * 0.75, size.height * 0.9)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: style.fillOpacity),
      );
    } else {
      path
        ..moveTo(size.width * 0.05, size.height * 0.75)
        ..lineTo(size.width * 0.4, size.height * 0.3)
        ..lineTo(size.width * 0.65, size.height * 0.65)
        ..lineTo(size.width * 0.95, size.height * 0.2);
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (!style.dashed) {
      canvas.drawPath(path, stroke);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += width * 5) {
        canvas.drawPath(metric.extractPath(d, d + width * 3), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.kind != kind ||
      old.style.colorValue != style.colorValue ||
      old.style.width != style.width ||
      old.style.dashed != style.dashed ||
      old.style.fillOpacity != style.fillOpacity;
}
