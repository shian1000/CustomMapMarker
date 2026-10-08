import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Translates between image space and the [CrsSimple] map space.
///
/// Positions are stored normalized (0..1 relative to the image), so they stay
/// valid regardless of image resolution or tiling. The image is laid out in a
/// box whose longer side spans one map unit, which keeps coordinates inside
/// valid latitude/longitude ranges and zoom levels in the usual 0..20 range
/// that flutter_map assumes (e.g. camera fitting clamps zoom at 0).
class MapCoordinateMapper {
  MapCoordinateMapper({required this.widthPx, required this.heightPx})
    : assert(widthPx > 0 && heightPx > 0),
      _unitsPerPx = _span / math.max(widthPx, heightPx);

  static const double _span = 1;
  static const double _top = 0;

  final int widthPx;
  final int heightPx;
  final double _unitsPerPx;

  /// Converts a normalized image position (0..1, origin top-left) to [LatLng].
  LatLng toLatLng(Offset normalized) => LatLng(
    _top - normalized.dy * heightPx * _unitsPerPx,
    normalized.dx * widthPx * _unitsPerPx,
  );

  /// Converts a map position back to a normalized image position.
  Offset toNormalized(LatLng point) => Offset(
    point.longitude / (widthPx * _unitsPerPx),
    (_top - point.latitude) / (heightPx * _unitsPerPx),
  );

  /// Whether [point] lies on the image.
  bool contains(LatLng point) {
    final n = toNormalized(point);
    return n.dx >= 0 && n.dx <= 1 && n.dy >= 0 && n.dy <= 1;
  }

  LatLngBounds get bounds =>
      LatLngBounds(toLatLng(Offset.zero), toLatLng(const Offset(1, 1)));

  /// Zoom at which one image pixel equals one logical screen pixel.
  double get nativeZoom => const CrsSimple().zoom(1 / _unitsPerPx);

  /// Zoom at which the whole image fits inside [viewport].
  double fitZoom(Size viewport) =>
      nativeZoom +
      _log2(math.min(viewport.width / widthPx, viewport.height / heightPx));

  static double _log2(double x) => math.log(x) / math.ln2;
}
