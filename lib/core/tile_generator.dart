import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_utils.dart';
import 'tile_pyramid.dart';

const _jpegQuality = 88;

/// Decodes the image at [imagePath] and writes its [TilePyramid] to
/// [tilesDir], reporting progress (0..1) through [report].
/// Returns the pyramid's max zoom.
///
/// Synchronous, slow and memory hungry (the full image is decoded) — run it in
/// an isolate.
int generateTiles(
  String imagePath,
  String tilesDir,
  void Function(double progress) report,
) {
  var level = _toPlainRgb(
    decodeDisplayableImage(File(imagePath).readAsBytesSync()),
  );
  final pyramid = TilePyramid(widthPx: level.width, heightPx: level.height);
  final total = pyramid.tileCount;
  // Decoding counts as a tenth of the work.
  report(0.1);

  var done = 0;
  for (var z = pyramid.maxZoom; z >= 0; z--) {
    if (z < pyramid.maxZoom) {
      level = img.copyResize(
        level,
        width: pyramid.levelWidth(z),
        height: pyramid.levelHeight(z),
        interpolation: img.Interpolation.average,
      );
    }
    for (var x = 0; x < pyramid.columns(z); x++) {
      Directory(TilePyramid.tilePath(tilesDir, z, x, 0)).parent
          .createSync(recursive: true);
      for (var y = 0; y < pyramid.rows(z); y++) {
        File(TilePyramid.tilePath(tilesDir, z, x, y))
            .writeAsBytesSync(_encodeTile(level, x, y));
        done++;
        report(0.1 + 0.9 * done / total);
      }
    }
  }
  return pyramid.maxZoom;
}

List<int> _encodeTile(img.Image level, int x, int y) {
  const size = TilePyramid.tileSize;
  final left = x * size;
  final top = y * size;
  final width = (level.width - left).clamp(0, size);
  final height = (level.height - top).clamp(0, size);
  final crop = _crop(level, left, top, width, height);

  final isFull = width == size && height == size;
  if (isFull && !level.hasAlpha) {
    return img.encodeJpg(crop, quality: _jpegQuality);
  }

  // Edge (or transparent) tile: pad to a full square with transparency so it
  // isn't stretched when drawn at tile size.
  final padded = img.Image(width: size, height: size, numChannels: 4);
  img.compositeImage(padded, crop, dstX: 0, dstY: 0);
  return img.encodePng(padded);
}

/// 8-bit RGB(A) without a palette, the layout [_crop] copies rows from.
img.Image _toPlainRgb(img.Image image) {
  final channels = image.hasAlpha ? 4 : 3;
  if (image.format == img.Format.uint8 &&
      !image.hasPalette &&
      image.numChannels == channels) {
    return image;
  }
  return image.convert(format: img.Format.uint8, numChannels: channels);
}

/// Copies whole pixel rows; img.copyCrop goes pixel by pixel and is ~100×
/// slower, which dominated tiling time.
img.Image _crop(img.Image source, int left, int top, int width, int height) {
  final channels = source.numChannels;
  final bytes = source.toUint8List();
  final sourceRow = source.width * channels;
  final row = width * channels;
  final out = Uint8List(row * height);
  for (var r = 0; r < height; r++) {
    final from = (top + r) * sourceRow + left * channels;
    out.setRange(r * row, (r + 1) * row, bytes, from);
  }
  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: out.buffer,
    numChannels: channels,
  );
}
