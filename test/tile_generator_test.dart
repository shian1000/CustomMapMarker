import 'dart:io';

import 'package:custom_map_marker/core/tile_generator.dart';
import 'package:custom_map_marker/core/tile_pyramid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('tiles'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// 600×300 image: left half red, right half blue.
  String writeSource({bool alpha = false}) {
    final image = img.Image(
      width: 600,
      height: 300,
      numChannels: alpha ? 4 : 3,
    );
    for (final px in image) {
      final red = px.x < 300;
      px
        ..r = red ? 255 : 0
        ..g = 0
        ..b = red ? 0 : 255
        ..a = alpha ? 128 : 255;
    }
    final path = '${tmp.path}/map.png';
    File(path).writeAsBytesSync(img.encodePng(image));
    return path;
  }

  img.Image tile(int z, int x, int y) => img.decodeImage(
    File(TilePyramid.tilePath('${tmp.path}/tiles', z, x, y)).readAsBytesSync(),
  )!;

  bool isJpeg(int z, int x, int y) =>
      File(TilePyramid.tilePath('${tmp.path}/tiles', z, x, y))
          .readAsBytesSync()
          .take(2)
          .toList()
          .toString() ==
      '[255, 216]';

  test('writes every tile of the pyramid as a full square', () {
    final maxZoom = generateTiles(writeSource(), '${tmp.path}/tiles', (_) {});
    final pyramid = TilePyramid(widthPx: 600, heightPx: 300);
    expect(maxZoom, pyramid.maxZoom);
    for (var z = 0; z <= maxZoom; z++) {
      for (var x = 0; x < pyramid.columns(z); x++) {
        for (var y = 0; y < pyramid.rows(z); y++) {
          final t = tile(z, x, y);
          expect((t.width, t.height), (256, 256), reason: 'tile $z/$x/$y');
        }
      }
    }
  });

  test('interior tiles are JPEG, edge tiles PNG padded with transparency', () {
    generateTiles(writeSource(), '${tmp.path}/tiles', (_) {});
    // Level 2 is 600×300: only tile (0,0) is fully covered.
    expect(isJpeg(2, 0, 0), isTrue);
    expect(isJpeg(2, 2, 0), isFalse);
    expect(isJpeg(2, 0, 1), isFalse);

    // Tile (2,0) covers x 512..599; beyond the image it is transparent.
    final edge = tile(2, 2, 0);
    expect(edge.getPixel(10, 10).a, 255);
    expect(edge.getPixel(100, 10).a, 0);
    // Tile (0,1) covers y 256..299.
    expect(tile(2, 0, 1).getPixel(10, 100).a, 0);
  });

  test('keeps image content in place on every level', () {
    generateTiles(writeSource(), '${tmp.path}/tiles', (_) {});
    // Full resolution: x=100 is red, tile (1,0) at x=600-512.. is blue.
    expect(tile(2, 0, 0).getPixel(100, 100).r, greaterThan(200));
    expect(tile(2, 1, 0).getPixel(200, 100).b, greaterThan(200));
    // Level 0 is 150×75: red up to x=75, blue after.
    final top = tile(0, 0, 0);
    expect(top.getPixel(30, 30).r, greaterThan(200));
    expect(top.getPixel(120, 30).b, greaterThan(200));
    expect(top.getPixel(200, 30).a, 0);
  });

  test('uses PNG for all tiles of a transparent image', () {
    generateTiles(writeSource(alpha: true), '${tmp.path}/tiles', (_) {});
    expect(isJpeg(2, 0, 0), isFalse);
    expect(tile(2, 0, 0).getPixel(10, 10).a, closeTo(128, 2));
  });

  test('reports increasing progress ending at 1', () {
    final reported = <double>[];
    generateTiles(writeSource(), '${tmp.path}/tiles', reported.add);
    expect(reported.first, closeTo(0.1, 1e-9));
    expect(reported.last, closeTo(1, 1e-9));
    for (var i = 1; i < reported.length; i++) {
      expect(reported[i], greaterThanOrEqualTo(reported[i - 1]));
    }
  });

  test('handles palette images', () {
    final rgb = img.Image(width: 600, height: 300);
    for (final px in rgb) {
      px
        ..r = px.x < 300 ? 255 : 0
        ..b = px.x < 300 ? 0 : 255;
    }
    final path = '${tmp.path}/palette.gif';
    File(path).writeAsBytesSync(img.encodeGif(rgb));
    generateTiles(path, '${tmp.path}/tiles', (_) {});
    expect(tile(2, 0, 0).getPixel(100, 100).r, greaterThan(200));
    expect(tile(2, 1, 0).getPixel(200, 100).b, greaterThan(200));
  });
}
