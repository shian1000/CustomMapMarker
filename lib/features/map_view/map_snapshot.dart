import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/coordinate_mapper.dart';
import '../../core/native_tile_renderer.dart';
import '../../core/tile_pyramid.dart';
import '../../data/map_marker.dart';
import '../../data/map_project.dart';
import '../../data/map_shape.dart';
import '../../shared/marker_colors.dart';
import '../../shared/marker_icons.dart';
import 'shape_layers.dart';

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
  List<MapShape> shapes = const [],
  bool showRouteNames = true,
  bool showAreaNames = true,
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

  // Shapes and markers in output pixels, sized to the output rather than the
  // screen.
  final pinSize = max(32.0, max(outWidth, outHeight) * 0.025);
  Offset toOutput(Offset normalized) => Offset(
    (normalized.dx * width - regionPx.left) * scale,
    (normalized.dy * height - regionPx.top) * scale,
  );
  // On screen a medium line (4 px) is a tenth of a pin (40 px).
  final strokeScale = pinSize / 40;
  final mapper = MapCoordinateMapper(
    widthPx: project.widthPx,
    heightPx: project.heightPx,
  );
  final ordered = [
    for (final s in shapes)
      if (s.kind == ShapeKind.area) s,
    for (final s in shapes)
      if (s.kind == ShapeKind.route) s,
  ];
  for (final shape in ordered) {
    _drawShape(canvas, shape, toOutput, strokeScale);
  }
  for (final shape in ordered) {
    final name = shape.name;
    if (name == null) continue;
    final Offset at;
    if (shape.kind == ShapeKind.area) {
      if (!showAreaNames) continue;
      at = toOutput(_areaLabelPoint(shape, mapper));
    } else {
      if (!showRouteNames) continue;
      at = _midpointAlong([for (final p in shape.points) toOutput(p)]);
    }
    _drawShapeName(canvas, name, at, pinSize * 0.35);
  }
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

void _drawShape(
  Canvas canvas,
  MapShape shape,
  Offset Function(Offset) toOutput,
  double strokeScale,
) {
  final color = Color(shape.colorValue);
  final width = strokeWidthOf(shape.style.width) * strokeScale;
  final points = [for (final p in shape.points) toOutput(p)];
  final path = Path()..addPolygon(points, shape.kind == ShapeKind.area);

  if (shape.kind == ShapeKind.area) {
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: shape.style.fillOpacity),
    );
  } else {
    // The same contrasting outline as on screen.
    _stroke(
      canvas,
      path,
      Paint()
        ..color = onColor(color).withValues(alpha: 0.7)
        ..strokeWidth = width + 2 * max(1, width / 3),
      dashed: shape.style.dashed,
      dashUnit: width,
    );
  }
  _stroke(
    canvas,
    path,
    Paint()
      ..color = color
      ..strokeWidth = width,
    dashed: shape.style.dashed,
    dashUnit: width,
  );
}

void _stroke(
  Canvas canvas,
  Path path,
  Paint paint, {
  required bool dashed,
  required double dashUnit,
}) {
  paint
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (!dashed) {
    canvas.drawPath(path, paint);
    return;
  }
  // Dash 3, gap 2 (in line widths), like on screen.
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += dashUnit * 5) {
      canvas.drawPath(metric.extractPath(d, d + dashUnit * 3), paint);
    }
  }
}

/// Where flutter_map puts an area's name: the point furthest inside it.
Offset _areaLabelPoint(MapShape area, MapCoordinateMapper mapper) {
  final label = const PolygonLabelPlacementCalculator.polylabel(
    precision: 0.0005,
  )(Polygon(points: [for (final p in area.points) mapper.toLatLng(p)]));
  return mapper.toNormalized(label);
}

Offset _midpointAlong(List<Offset> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).distance;
  }
  var remaining = total / 2;
  for (var i = 1; i < points.length; i++) {
    final segment = points[i] - points[i - 1];
    final length = segment.distance;
    if (remaining <= length && length > 0) {
      return points[i - 1] + segment * (remaining / length);
    }
    remaining -= length;
  }
  return points.last;
}

/// Dark text with a light halo, like shape names on screen.
void _drawShapeName(Canvas canvas, String name, Offset center, double size) {
  final text = TextPainter(
    text: TextSpan(
      text: name,
      style: shapeLabelStyle.copyWith(
        fontSize: size,
        shadows: [
          Shadow(color: Colors.white, blurRadius: size / 5),
          Shadow(color: Colors.white, blurRadius: size / 2.5),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: size * 20);
  text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
}
