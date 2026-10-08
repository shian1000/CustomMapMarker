import 'package:custom_map_marker/core/tile_pyramid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('top zoom is the first level whose size fits the longer side', () {
    expect(TilePyramid.topZoomFor(1), 0);
    expect(TilePyramid.topZoomFor(256), 0);
    expect(TilePyramid.topZoomFor(257), 1);
    expect(TilePyramid.topZoomFor(4096), 4);
    expect(TilePyramid.topZoomFor(4097), 5);
    expect(TilePyramid.topZoomFor(10000), 6);
  });

  test('levels halve the image rounding up, down to one tile', () {
    final p = TilePyramid(widthPx: 600, heightPx: 300);
    expect(p.maxZoom, 2);
    expect(
      [for (var z = 0; z <= 2; z++) (p.levelWidth(z), p.levelHeight(z))],
      [(150, 75), (300, 150), (600, 300)],
    );
    expect(
      [for (var z = 0; z <= 2; z++) (p.columns(z), p.rows(z))],
      [(1, 1), (2, 1), (3, 2)],
    );
    expect(p.tileCount, 1 + 2 + 6);
  });

  test('contains only existing tiles', () {
    final p = TilePyramid(widthPx: 600, heightPx: 300);
    expect(p.contains(2, 1, 2), isTrue);
    expect(p.contains(3, 0, 2), isFalse);
    expect(p.contains(0, 2, 2), isFalse);
    expect(p.contains(-1, 0, 1), isFalse);
    expect(p.contains(0, 0, 3), isFalse);
  });
}
