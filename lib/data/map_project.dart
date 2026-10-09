import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
class MapProject {
  const MapProject({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
    this.tileMaxZoom,
    this.metersPerPixel,
  });

  final String id;
  final String name;

  /// Copy of the imported image inside the app documents directory.
  final String imagePath;
  final int widthPx;
  final int heightPx;
  final DateTime createdAt;

  /// Top level of the tile pyramid, or null for single-image maps.
  final int? tileMaxZoom;

  bool get isTiled => tileMaxZoom != null;

  /// Real-world meters per image pixel; null until the scale is set.
  final double? metersPerPixel;

  /// Directory holding the tile pyramid of a tiled map.
  String get tilesDir => p.join(p.dirname(imagePath), 'tiles');
}

/// A map as shown in the maps list.
@immutable
class MapSummary {
  const MapSummary({required this.map, required this.markerCount});

  final MapProject map;
  final int markerCount;
}
