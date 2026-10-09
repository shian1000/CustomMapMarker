import 'dart:math';
import 'dart:ui';

/// Lengths and areas of shapes given in normalized image coordinates (0..1),
/// in image pixels and, with a scale, in meters.
class MapMeasure {
  const MapMeasure({
    required this.widthPx,
    required this.heightPx,
    this.metersPerPixel,
  });

  final int widthPx;
  final int heightPx;
  final double? metersPerPixel;

  bool get hasScale => metersPerPixel != null;

  Offset _px(Offset normalized) =>
      Offset(normalized.dx * widthPx, normalized.dy * heightPx);

  /// Length along [points] in image pixels; [closed] adds the segment from
  /// the last point back to the first (an area's perimeter).
  double lengthPx(List<Offset> points, {bool closed = false}) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (_px(points[i]) - _px(points[i - 1])).distance;
    }
    if (closed && points.length > 2) {
      total += (_px(points.first) - _px(points.last)).distance;
    }
    return total;
  }

  /// Area enclosed by [points] in square image pixels (shoelace formula).
  double areaPx(List<Offset> points) {
    var twice = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = _px(points[i]);
      final b = _px(points[(i + 1) % points.length]);
      twice += a.dx * b.dy - b.dx * a.dy;
    }
    return twice.abs() / 2;
  }

  /// Length in meters, or null without a scale.
  double? lengthMeters(List<Offset> points, {bool closed = false}) {
    final scale = metersPerPixel;
    return scale == null ? null : lengthPx(points, closed: closed) * scale;
  }

  /// Area in square meters, or null without a scale.
  double? areaSquareMeters(List<Offset> points) {
    final scale = metersPerPixel;
    return scale == null ? null : areaPx(points) * scale * scale;
  }
}

/// Units the scale can be entered in.
enum DistanceUnit {
  kilometers('km', 1000),
  meters('m', 1),
  miles('mi', 1609.344);

  const DistanceUnit(this.symbol, this.inMeters);

  final String symbol;

  /// Length of one unit in meters.
  final double inMeters;
}

/// "340 m", "4,2 km", "12 500 km": Polish decimal comma, spaced thousands.
String formatDistance(double meters) {
  if (meters < 1000) return '${_group(meters.round())} m';
  final km = meters / 1000;
  if (km < 10) return '${_decimal(km, 1)} km';
  return '${_group(km.round())} km';
}

/// "850 m²", "3,4 ha" (1 ha = 10 000 m²), "12 500 km²".
String formatArea(double squareMeters) {
  if (squareMeters < 10000) return '${_group(squareMeters.round())} m²';
  if (squareMeters < 1000000) {
    final ha = squareMeters / 10000;
    return ha < 10 ? '${_decimal(ha, 1)} ha' : '${_group(ha.round())} ha';
  }
  final km2 = squareMeters / 1000000;
  return km2 < 10 ? '${_decimal(km2, 1)} km²' : '${_group(km2.round())} km²';
}

/// Image pixels, for when there is no scale: "1 240 px".
String formatPixels(double px) => '${_group(px.round())} px';

String _decimal(double value, int digits) {
  final text = value.toStringAsFixed(digits).replaceAll('.', ',');
  return text.endsWith(',0') ? text.substring(0, text.length - 2) : text;
}

/// Thousands separated by a non-breaking space, as Polish style has it.
String _group(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A round length (1, 2 or 5 × 10ⁿ meters) at most [maxMeters], for a
/// scale bar.
double niceScaleLength(double maxMeters) {
  // The epsilon keeps exact powers of ten (log10(1000) = 2.9999…) whole.
  final exponent = pow(10, (log(maxMeters) / ln10 + 1e-9).floor()).toDouble();
  for (final step in const [5, 2, 1]) {
    if (step * exponent <= maxMeters) return step * exponent;
  }
  return exponent;
}
