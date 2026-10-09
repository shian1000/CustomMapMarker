import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/map_shape.dart';
import '../../shared/marker_colors.dart';

/// Line widths in logical pixels for [ShapeWidth].
double strokeWidthOf(ShapeWidth width) => switch (width) {
  ShapeWidth.thin => 2,
  ShapeWidth.medium => 4,
  ShapeWidth.thick => 7,
};

StrokePattern _pattern(ShapeStyle style) => style.dashed
    ? StrokePattern.dashed(
        segments: [
          strokeWidthOf(style.width) * 3,
          strokeWidthOf(style.width) * 2,
        ],
      )
    : const StrokePattern.solid();

/// Dark text with a light halo, readable on any map.
const shapeLabelStyle = TextStyle(
  color: Color(0xFF1B1B1B),
  fontSize: 14,
  fontWeight: FontWeight.w700,
  shadows: [
    Shadow(color: Colors.white, blurRadius: 3),
    Shadow(color: Colors.white, blurRadius: 6),
  ],
);

Polygon<String> areaPolygon(
  List<LatLng> points,
  ShapeStyle style, {
  String? hitValue,
  bool showName = true,
}) {
  final color = Color(style.colorValue);
  return Polygon<String>(
    points: points,
    color: color.withValues(alpha: style.fillOpacity),
    borderColor: color,
    borderStrokeWidth: strokeWidthOf(style.width),
    pattern: _pattern(style),
    label: showName ? style.name : null,
    labelStyle: shapeLabelStyle,
    // Inside the area even for concave (C-shaped) outlines.
    labelPlacementCalculator: const PolygonLabelPlacementCalculator.polylabel(),
    hitValue: hitValue,
  );
}

Polyline<String> routePolyline(
  List<LatLng> points,
  ShapeStyle style, {
  String? hitValue,
}) {
  final color = Color(style.colorValue);
  final width = strokeWidthOf(style.width);
  return Polyline<String>(
    points: points,
    color: color,
    strokeWidth: width,
    pattern: _pattern(style),
    // A thin outline in the opposite tone keeps the line visible on maps
    // of a similar color.
    borderColor: onColor(color).withValues(alpha: 0.7),
    borderStrokeWidth: max(1, width / 3),
    hitValue: hitValue,
  );
}

/// The point halfway along [points], measured by length.
LatLng midpointAlong(List<LatLng> points) {
  if (points.length == 1) return points.single;
  double segment(LatLng a, LatLng b) =>
      sqrt(pow(b.latitude - a.latitude, 2) + pow(b.longitude - a.longitude, 2));

  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += segment(points[i - 1], points[i]);
  }
  var remaining = total / 2;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final length = segment(a, b);
    if (remaining <= length && length > 0) {
      final t = remaining / length;
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    remaining -= length;
  }
  return points.last;
}

/// A route's name, centered on [point].
Marker routeLabel(String id, LatLng point, String name) => Marker(
  key: ValueKey('route-label:$id'),
  point: point,
  width: 180,
  height: 24,
  child: IgnorePointer(
    child: Center(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: shapeLabelStyle,
      ),
    ),
  ),
);
