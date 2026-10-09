import 'dart:ui';

import 'package:flutter/foundation.dart';

enum ShapeKind {
  route,
  area;

  /// Fewest points that make a shape of this kind.
  int get minPoints => switch (this) {
    route => 2,
    area => 3,
  };
}

enum ShapeWidth { thin, medium, thick }

/// A route (open line) or area (closed, filled polygon) on a map. Its points
/// are its own, normalized to the image (0..1), and independent of markers.
@immutable
class MapShape {
  const MapShape({
    required this.id,
    required this.mapId,
    required this.kind,
    required this.points,
    required this.style,
    required this.createdAt,
  });

  final String id;
  final String mapId;
  final ShapeKind kind;
  final List<Offset> points;
  final ShapeStyle style;
  final DateTime createdAt;

  String? get name => style.name;
  int get colorValue => style.colorValue;
}

/// User-editable fields of a shape, as produced by the shape editor.
@immutable
class ShapeStyle {
  const ShapeStyle({
    this.name,
    this.description,
    required this.colorValue,
    this.width = ShapeWidth.medium,
    this.dashed = false,
    this.fillOpacity = 0.3,
  });

  final String? name;
  final String? description;
  final int colorValue;

  /// Line width of a route, or border width of an area.
  final ShapeWidth width;
  final bool dashed;

  /// Areas only.
  final double fillOpacity;
}
