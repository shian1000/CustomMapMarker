import 'package:flutter/material.dart';

import '../marker_colors.dart';

/// A colored pin with its label above. Its bottom-center is the pin tip, so
/// place it with [Alignment.topCenter] in a flutter_map `Marker`.
class MarkerPin extends StatelessWidget {
  const MarkerPin({
    super.key,
    required this.label,
    required this.color,
    this.highlighted = false,
    this.emphasized = false,
    this.icon,
    this.onTap,
  });

  static const double width = 160;
  static const double height = 64;
  static const double _iconSize = 40;

  /// The location_on glyph's tip sits ~2/24 above the bottom of its box.
  static const double _tipInset = _iconSize * 2 / 24;

  final String label;
  final Color color;
  final bool highlighted;

  /// Briefly enlarges the pin, e.g. after flying to it from the marker list.
  final bool emphasized;

  /// Drawn inside the pin's head; null for the plain pin.
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.black26,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black38)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: onColor(color),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedScale(
        scale: emphasized ? 1.3 : 1,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: onTap,
          child: Transform.translate(
            offset: const Offset(0, _tipInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                PinGlyph(
                  color: color,
                  icon: icon,
                  size: _iconSize,
                  shadows: [
                    Shadow(
                      blurRadius: highlighted ? 6 : 3,
                      color: highlighted ? Colors.white : Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pin shape alone, optionally with [icon] in its round head. Also used
/// at small sizes in lists.
class PinGlyph extends StatelessWidget {
  const PinGlyph({
    super.key,
    required this.color,
    this.icon,
    this.size = 24,
    this.shadows,
  });

  final Color color;
  final IconData? icon;
  final double size;
  final List<Shadow>? shadows;

  // Geometry of the location_on glyph in its 24-unit box: the round head is
  // centered at (12, 9) with a radius of about 7.
  static const double _headCenterY = 9 / 24;
  static const double _headRadius = 6 / 24;

  @override
  Widget build(BuildContext context) {
    final pin = Icon(
      Icons.location_on,
      size: size,
      color: color,
      shadows: shadows,
    );
    final icon = this.icon;
    if (icon == null) return pin;

    final head = size * _headRadius * 2;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          pin,
          Positioned(
            left: (size - head) / 2,
            top: size * _headCenterY - head / 2,
            child: Container(
              width: head,
              height: head,
              // Covers the glyph's hole so the icon sits on solid color.
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: head * 0.8, color: onColor(color)),
            ),
          ),
        ],
      ),
    );
  }
}
