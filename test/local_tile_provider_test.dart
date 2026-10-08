import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:custom_map_marker/core/native_tile_renderer.dart';
import 'package:custom_map_marker/core/tile_pyramid.dart';
import 'package:custom_map_marker/features/map_view/local_tile_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

  testWidgets('a tile dropped during a slow render does not throw '
      'and loads from disk next time', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('tiles');
      addTearDown(() => dir.deleteSync(recursive: true));
      final renderer = _SlowRenderer();
      final slow = LocalTileProvider(
        tilesDir: dir.path,
        imagePath: '/map.png',
        pyramid: TilePyramid(widthPx: 600, heightPx: 300),
        renderer: renderer,
      );

      // Request the tile, then drop it before the render finishes, like
      // flutter_map does when the view changes. Errors from the dropped load
      // surface asynchronously, so catch them in a zone of our own.
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final first = slow.getImage(
          const TileCoordinates(0, 0, 0),
          TileLayer(),
        );
        // Load directly, without the image cache keeping the stream alive, so
        // removing the only listener disposes it as on the phone.
        // ignore: invalid_use_of_protected_member
        final completer = first.loadImage(
          first,
          (buffer, {getTargetSize}) =>
              ui.instantiateImageCodecFromBuffer(buffer),
        );
        final listener = ImageStreamListener((_, _) {});
        completer.addListener(listener);
        await Future<void>.delayed(Duration.zero);
        completer.removeListener(listener);

        renderer.finish();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);

      // The next request reuses the rendered file.
      final loaded = Completer<ImageInfo>();
      slow
          .getImage(const TileCoordinates(0, 0, 0), TileLayer())
          .resolve(ImageConfiguration.empty)
          .addListener(ImageStreamListener((info, _) => loaded.complete(info)));
      final info = await loaded.future.timeout(const Duration(seconds: 5));
      expect(info.image.width, 256);
      expect(renderer.calls, 1);
    });
  });
}

/// Renders one tile only when told to, writing a real 256×256 PNG.
class _SlowRenderer implements NativeTileRenderer {
  final _go = Completer<void>();
  int calls = 0;

  void finish() => _go.complete();

  @override
  Future<void> render({
    required String imagePath,
    required String outPath,
    required int zoom,
    required int x,
    required int y,
    required int maxZoom,
  }) async {
    calls++;
    await _go.future;
    File(outPath)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(img.Image(width: 256, height: 256)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
