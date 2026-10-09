import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/measure.dart';

/// A Google-Maps-style scale bar in the bottom-left corner. A child of
/// FlutterMap that stays put on screen and follows the zoom.
class ScaleBar extends StatelessWidget {
  const ScaleBar({
    super.key,
    required this.metersPerPixel,
    required this.nativeZoom,
  });

  /// Meters per image pixel.
  final double metersPerPixel;

  /// Zoom at which one image pixel is one logical screen pixel.
  final double nativeZoom;

  static const double _maxWidth = 100;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final metersPerScreenPx = metersPerPixel * pow(2, nativeZoom - zoom);
    final meters = niceScaleLength(_maxWidth * metersPerScreenPx);
    final width = meters / metersPerScreenPx;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDistance(meters), style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Container(
                  width: width,
                  height: 6,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: ink, width: 2),
                      right: BorderSide(color: ink, width: 2),
                      bottom: BorderSide(color: ink, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
