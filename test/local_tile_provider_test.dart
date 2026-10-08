import 'package:custom_map_marker/core/tile_pyramid.dart';
import 'package:custom_map_marker/features/map_view/local_tile_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final provider = LocalTileProvider(
    tilesDir: '/tiles',
    imagePath: '/map.jpg',
    pyramid: TilePyramid(widthPx: 5456, heightPx: 7567),
  );

  String? pathOf(ImageProvider image) {
    final key = image.toString();
    final match = RegExp(r'/tiles/\d+/\d+/\d+').firstMatch(key);
    return match?.group(0);
  }

  test('applies the layer zoom offset to the tile level', () {
    final layer = TileLayer(zoomOffset: 2, tileDimension: 64);
    final image = provider.getImage(const TileCoordinates(10, 20, 3), layer);
    expect(pathOf(image), '/tiles/5/10/20');
  });

  test('uses the level as is without an offset', () {
    final image = provider.getImage(
      const TileCoordinates(1, 2, 3),
      TileLayer(),
    );
    expect(pathOf(image), '/tiles/3/1/2');
  });

  test('returns an empty image outside the pyramid', () {
    // Level 5 of 5456×7567 has 22×30 tiles.
    final layer = TileLayer(zoomOffset: 2, tileDimension: 64);
    final image = provider.getImage(const TileCoordinates(22, 0, 3), layer);
    expect(image, isA<MemoryImage>());
  });
}
