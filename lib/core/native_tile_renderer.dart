import 'dart:io';

import 'package:flutter/services.dart';

/// Thrown by [NativeTileRenderer.generateAll] when the image is too large to
/// decode at once on this device.
class ImageTooLargeException implements Exception {
  const ImageTooLargeException(this.message);

  final String? message;

  @override
  String toString() => 'ImageTooLargeException: $message';
}

/// Renders map tiles with the platform's image decoders (see
/// android/.../TileRenderer.kt). Only available on Android so far; elsewhere
/// tiles are generated in Dart (see tile_generator.dart), which is much slower.
class NativeTileRenderer {
  const NativeTileRenderer();

  static const _channel = MethodChannel('custom_map_marker/tiles');

  static bool get isSupported => Platform.isAndroid;

  /// Formats the Android decoders can read.
  static const supportedFormats = {'jpeg', 'png', 'webp'};

  /// Formats whose regions can be decoded quickly, so tiles can be rendered
  /// on demand while viewing. PNG and WebP have to be decoded from the top
  /// for every region, so their tiles are all generated at import instead.
  static const onDemandFormats = {'jpeg'};

  static var _nextTaskId = 0;
  static final _progressListeners = <int, void Function(double)>{};

  /// Decodes the whole image once and writes every tile of its pyramid to
  /// [tilesDir]. Throws [ImageTooLargeException] if it doesn't fit in memory.
  Future<void> generateAll({
    required String imagePath,
    required String tilesDir,
    required int maxZoom,
    void Function(double progress)? onProgress,
  }) async {
    _channel.setMethodCallHandler(_handleCall);
    final taskId = _nextTaskId++;
    if (onProgress != null) _progressListeners[taskId] = onProgress;
    try {
      await _channel.invokeMethod<void>('generateAllTiles', {
        'imagePath': imagePath,
        'tilesDir': tilesDir,
        'maxZoom': maxZoom,
        'taskId': taskId,
      });
    } on PlatformException catch (e) {
      if (e.code == 'TOO_LARGE') throw ImageTooLargeException(e.message);
      rethrow;
    } finally {
      _progressListeners.remove(taskId);
    }
  }

  static Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'progress') return;
    final args = call.arguments as Map;
    _progressListeners[args['taskId'] as int]?.call(
      (args['value'] as num).toDouble(),
    );
  }

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
