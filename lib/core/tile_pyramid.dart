import 'dart:math' as math;

import 'package:path/path.dart' as p;

/// Layout of the tile pyramid generated for large maps.
///
/// Level [maxZoom] holds the image at full resolution; every level below
/// halves it (rounding up), down to level 0 where the longer side fits one
/// tile. Tiles are [tileSize] squares; tiles on the right and bottom edges are
/// padded with transparency.
class TilePyramid {
  TilePyramid({required this.widthPx, required this.heightPx})
    : maxZoom = topZoomFor(math.max(widthPx, heightPx));

  static const tileSize = 256;

  final int widthPx;
  final int heightPx;
  final int maxZoom;

  /// Smallest zoom at which [maxSidePx] fits in `tileSize * 2^zoom` pixels.
  static int topZoomFor(int maxSidePx) {
    var zoom = 0;
    while ((tileSize << zoom) < maxSidePx) {
      zoom++;
    }
    return zoom;
  }

  int levelWidth(int zoom) => _scaled(widthPx, zoom);
  int levelHeight(int zoom) => _scaled(heightPx, zoom);

  int columns(int zoom) => (levelWidth(zoom) / tileSize).ceil();
  int rows(int zoom) => (levelHeight(zoom) / tileSize).ceil();

  int get tileCount =>
      [for (var z = 0; z <= maxZoom; z++) columns(z) * rows(z)]
          .fold(0, (a, b) => a + b);

  bool contains(int x, int y, int zoom) =>
      zoom >= 0 &&
      zoom <= maxZoom &&
      x >= 0 &&
      y >= 0 &&
      x < columns(zoom) &&
      y < rows(zoom);

  /// Tiles have no extension: interior tiles are JPEG, edge tiles PNG, and
  /// image decoders detect the format from content.
  static String tilePath(String tilesDir, int zoom, int x, int y) =>
      p.join(tilesDir, '$zoom', '$x', '$y');

  int _scaled(int size, int zoom) => (size / (1 << (maxZoom - zoom))).ceil();
}
