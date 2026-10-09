import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/native_tile_renderer.dart';
import '../../core/tile_pyramid.dart';
import '../../data/map_marker.dart';
import '../../data/map_project.dart';
import '../../shared/marker_colors.dart';
import '../../shared/marker_icons.dart';

/// Renders [region] of [project] (normalized, 0..1 of the image) with
/// [markers] drawn on top, as PNG bytes at most [maxSide] px on the longer
/// side.
///
/// Small maps are drawn from their image; tiled maps from the lowest pyramid
/// level that is sharp enough, so a 40 MP image is never decoded at once.
/// Missing tiles are rendered through [renderer] when given.
Future<Uint8List> renderMapSnapshot({
  required MapProject project,
  required List<MapMarker> markers,
  Rect region = const Rect.fromLTWH(0, 0, 1, 1),
  int maxSide = 4096,
  NativeTileRenderer? renderer,
}) async {
  final width = project.widthPx.toDouble();
  final height = project.heightPx.toDouble();
  final regionPx = Rect.fromLTRB(
    region.left * width,
    region.top * height,
    region.right * width,
    region.bottom * height,
  );
  final scale = min(1.0, maxSide / max(regionPx.width, regionPx.height));
  final outWidth = max(1, (regionPx.width * scale).round());
  final outHeight = max(1, (regionPx.height * scale).round());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipRect(
    Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
  );

  // Draw the map in image pixel coordinates.
  canvas
    ..save()
    ..scale(scale)
    ..translate(-regionPx.left, -regionPx.top);
  final paint = Paint()..filterQuality = FilterQuality.high;
  if (project.tileMaxZoom case final maxZoom?) {
    await _drawTiles(
      canvas,
      paint,
      project,
      maxZoom,
      regionPx,
      scale,
      renderer,
    );
  } else {
    final image = await _decodeFile(project.imagePath);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width, height),
      paint,
    );
    image.dispose();
  }
  canvas.restore();

  // Markers in output pixels, sized to the output rather than the screen.
  final pinSize = max(32.0, max(outWidth, outHeight) * 0.025);
  for (final m in markers) {
    final tip = Offset(
      (m.x * width - regionPx.left) * scale,
      (m.y * height - regionPx.top) * scale,
    );
    if (tip.dx < -pinSize * 3 ||
        tip.dy < -pinSize ||
        tip.dx > outWidth + pinSize * 3 ||
        tip.dy > outHeight + pinSize * 2) {
      continue;
    }
    _drawPin(
      canvas,
      tip: tip,
      size: pinSize,
      color: Color(m.colorValue),
      icon: markerIconFor(m.icon)?.icon,
      label: m.label,
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(outWidth, outHeight);
  picture.dispose();
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Pyramid levels below the needed scale are allowed down to this fraction:
/// slight upscaling is invisible, and each level down quarters the tiles.
const _levelScaleTolerance = 0.75;

Future<void> _drawTiles(
  Canvas canvas,
  Paint paint,
  MapProject project,
  int maxZoom,
  Rect regionPx,
  double scale,
  NativeTileRenderer? renderer,
) async {
  final pyramid = TilePyramid(
    widthPx: project.widthPx,
    heightPx: project.heightPx,
  );
  // Lowest level whose resolution is close enough to the output's.
  var zoom = maxZoom;
  while (zoom > 0 &&
      pow(2, zoom - 1 - maxZoom) >= scale * _levelScaleTolerance) {
    zoom--;
  }
  // One tile of this level covers this many image pixels.
  final span = (TilePyramid.tileSize << (maxZoom - zoom)).toDouble();

  final firstX = max(0, (regionPx.left / span).floor());
  final firstY = max(0, (regionPx.top / span).floor());
  final lastX = min(
    pyramid.columns(zoom) - 1,
    (regionPx.right / span).ceil() - 1,
  );
  final lastY = min(
    pyramid.rows(zoom) - 1,
    (regionPx.bottom / span).ceil() - 1,
  );

  for (var x = firstX; x <= lastX; x++) {
    for (var y = firstY; y <= lastY; y++) {
      final path = TilePyramid.tilePath(project.tilesDir, zoom, x, y);
      if (!await File(path).exists()) {
        if (renderer == null) throw StateError('Missing tile $path');
        await renderer.render(
          imagePath: project.imagePath,
          outPath: path,
          zoom: zoom,
          x: x,
          y: y,
          maxZoom: maxZoom,
        );
      }
      final tile = await _decodeFile(path);
      canvas.drawImageRect(
        tile,
        Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble()),
        Rect.fromLTWH(x * span, y * span, span, span),
        paint,
      );
      tile.dispose();
    }
  }
}

Future<ui.Image> _decodeFile(String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await File(path).readAsBytes(),
  );
  final codec = await ui.instantiateImageCodecFromBuffer(buffer);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Draws a pin like MarkerPin: the location_on glyph with its tip at [tip],
/// an optional [icon] in its head and [label] in a bubble above.
void _drawPin(
  Canvas canvas, {
  required Offset tip,
  required double size,
  required Color color,
  required IconData? icon,
  required String label,
}) {
  // location_on in its 24-unit box: tip ~2 units above the bottom, round head
  // centered at (12, 9) with a radius of about 7.
  final top = tip.dy - size + size * 2 / 24;
  final left = tip.dx - size / 2;

  _glyph(
    Icons.location_on,
    size,
    color,
    shadows: [Shadow(blurRadius: size / 12, color: Colors.black54)],
  ).paint(canvas, Offset(left, top));

  if (icon != null) {
    final center = Offset(tip.dx, top + size * 9 / 24);
    final radius = size * 6 / 24;
    canvas.drawCircle(center, radius, Paint()..color = color);
    final glyph = _glyph(icon, radius * 1.6, onColor(color));
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  }

  final text = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: onColor(color),
        fontSize: size * 0.32,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: size * 5);
  final padding = EdgeInsets.symmetric(
    horizontal: size * 0.15,
    vertical: size * 0.05,
  );
  final bubble = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(tip.dx, top - text.height / 2 - padding.vertical / 2),
      width: text.width + padding.horizontal,
      height: text.height + padding.vertical,
    ),
    Radius.circular(size * 0.15),
  );
  canvas
    ..drawRRect(
      bubble.shift(Offset(0, size * 0.03)),
      Paint()
        ..color = Colors.black38
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.05),
    )
    ..drawRRect(bubble, Paint()..color = color)
    ..drawRRect(
      bubble,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, size / 40),
    );
  text.paint(
    canvas,
    Offset(bubble.left + padding.left, bubble.top + padding.top),
  );
}

TextPainter _glyph(
  IconData icon,
  double size,
  Color color, {
  List<Shadow>? shadows,
}) => TextPainter(
  text: TextSpan(
    text: String.fromCharCode(icon.codePoint),
    style: TextStyle(
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontSize: size,
      height: 1,
      color: color,
      shadows: shadows,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();
