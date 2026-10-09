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
                Icon(
                  Icons.location_on,
                  size: _iconSize,
                  color: color,
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
