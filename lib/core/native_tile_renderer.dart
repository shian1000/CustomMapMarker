import 'dart:io';

import 'package:flutter/services.dart';

/// Renders map tiles on demand with the platform's region decoder (see
/// android/.../TileRenderer.kt). Only available on Android so far; elsewhere
/// tiles are generated up front in Dart (see tile_generator.dart).
class NativeTileRenderer {
  const NativeTileRenderer();

  static const _channel = MethodChannel('custom_map_marker/tiles');

  static bool get isSupported => Platform.isAndroid;

  /// Formats the Android region decoder can read.
  static const supportedFormats = {'jpeg', 'png', 'webp'};

  /// Renders tile [zoom]/[x]/[y] of the image at [imagePath] into [outPath].
  Future<void> render({
    required String imagePath,
    required String outPath,
    required int zoom,
    required int x,
    required int y,
    required int maxZoom,
  }) => _channel.invokeMethod<void>('renderTile', {
    'imagePath': imagePath,
    'outPath': outPath,
    'zoom': zoom,
    'x': x,
    'y': y,
    'maxZoom': maxZoom,
  });
}
