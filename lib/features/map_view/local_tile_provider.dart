import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/native_tile_renderer.dart';
import '../../core/tile_pyramid.dart';

/// Serves tiles of a [TilePyramid] stored in [tilesDir]. Tiles missing on
/// disk are rendered from [imagePath] by [renderer] and kept for next time.
class LocalTileProvider extends TileProvider {
  LocalTileProvider({
    required this.tilesDir,
    required this.imagePath,
    required this.pyramid,
    this.renderer,
  });

  final String tilesDir;
  final String imagePath;
  final TilePyramid pyramid;
  final NativeTileRenderer? renderer;

  /// 1×1 transparent PNG for coordinates outside the pyramid, which
  /// flutter_map can still ask for at the edges of `tileBounds`.
  static final _empty = MemoryImage(
    Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // With a zoom offset (see MapViewScreen), x/y already address the
    // higher level but z doesn't include the offset yet.
    final TileCoordinates(:x, :y) = coordinates;
    final z = coordinates.z + options.zoomOffset.round();
    if (!pyramid.contains(x, y, z)) return _empty;
    return _TileImage(
      path: TilePyramid.tilePath(tilesDir, z, x, y),
      render: renderer == null
          ? null
          : (outPath) => renderer!.render(
              imagePath: imagePath,
              outPath: outPath,
              zoom: z,
              x: x,
              y: y,
              maxZoom: pyramid.maxZoom,
            ),
    );
  }
}

/// A tile file, rendered first through [render] if it doesn't exist yet.
@immutable
class _TileImage extends ImageProvider<_TileImage> {
  const _TileImage({required this.path, this.render});

  final String path;
  final Future<void> Function(String outPath)? render;

  @override
  Future<_TileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final file = File(path);
    if (!await file.exists()) {
      final render = this.render;
      if (render == null) throw StateError('Missing tile $path');
      await render(path);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  // Equality by path lets the image cache share in-flight loads of a tile.
  @override
  bool operator ==(Object other) => other is _TileImage && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => '_TileImage($path)';
}
