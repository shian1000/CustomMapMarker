import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/image_utils.dart';
import '../core/isolate_progress.dart';
import '../core/native_tile_renderer.dart';
import '../core/tile_generator.dart';
import '../core/tile_pyramid.dart';
import 'database.dart';
import 'map_project.dart';

class MapRepository {
  MapRepository(
    this._db,
    this._documentsDir, {
    this.tilingThresholdPx = defaultTilingThresholdPx,
    this.nativeTiles,
  });

  /// Larger images exceed common GPU texture limits (and get blurry or fail
  /// to draw as one image), so they are shown as tiles.
  static const defaultTilingThresholdPx = 4096;

  final AppDatabase _db;
  final Directory _documentsDir;
  final int tilingThresholdPx;

  /// Native tile rendering, when the platform has it (see [_prepareTiles]).
  /// Without it, all tiles are generated up front in Dart, which is much
  /// slower.
  final NativeTileRenderer? nativeTiles;

  static const _uuid = Uuid();

  /// All maps with their marker counts, newest first.
  Stream<List<MapSummary>> watchMaps() {
    final markerCount = _db.markers.id.count();
    final query =
        _db.select(_db.maps).join([
            leftOuterJoin(
              _db.markers,
              _db.markers.mapId.equalsExp(_db.maps.id),
              useColumns: false,
            ),
          ])
          ..addColumns([markerCount])
          ..groupBy([_db.maps.id])
          ..orderBy([OrderingTerm.desc(_db.maps.createdAt)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          MapSummary(
            map: _toProject(row.readTable(_db.maps)),
            markerCount: row.read(markerCount) ?? 0,
          ),
      ],
    );
  }

  /// Copies the image at [sourcePath] into app storage, tiles it when large,
  /// and saves it as a map named [name] (default: the file name).
  /// [onProgress] receives 0..1 while tiling.
  Future<MapProject> importImage(
    String sourcePath, {
    String? name,
    void Function(double progress)? onProgress,
  }) async {
    final id = _uuid.v4();
    final dir = await _mapDir(id).create(recursive: true);

    try {
      final image = await Isolate.run(
        () => prepareMapImage(sourcePath, dir.path),
      );

      final tileMaxZoom =
          math.max(image.width, image.height) > tilingThresholdPx
          ? await _prepareTiles(
              imagePath: image.path,
              format: image.format,
              width: image.width,
              height: image.height,
              onProgress: onProgress,
            )
          : null;

      final row = MapRow(
        id: id,
        name: name ?? p.basenameWithoutExtension(sourcePath),
        imageFile: p.relative(image.path, from: _documentsDir.path),
        widthPx: image.width,
        heightPx: image.height,
        createdAt: DateTime.now(),
        tileMaxZoom: tileMaxZoom,
      );
      await _db.into(_db.maps).insert(row);
      return _toProject(row);
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  /// Whether [map] was imported before tiling existed and is large enough to
  /// benefit from it (see [enableTiling]).
  bool canEnableTiling(MapProject map) =>
      !map.isTiled && math.max(map.widthPx, map.heightPx) > tilingThresholdPx;

  /// Switches a large single-image map to tiles. Markers are unaffected since
  /// they are stored relative to the image.
  Future<void> enableTiling(
    MapProject map, {
    void Function(double progress)? onProgress,
  }) async {
    if (!canEnableTiling(map)) return;
    final imagePath = map.imagePath;
    final format = await Isolate.run(() => detectImageFormat(imagePath));
    final tileMaxZoom = await _prepareTiles(
      imagePath: imagePath,
      format: format,
      width: map.widthPx,
      height: map.heightPx,
      onProgress: onProgress,
    );
    await (_db.update(_db.maps)..where((m) => m.id.equals(map.id))).write(
      MapsCompanion(tileMaxZoom: Value(tileMaxZoom)),
    );
  }

  /// Returns the pyramid's top zoom, generating tiles now unless they can be
  /// rendered on demand while viewing:
  /// - JPEG with native rendering: nothing to do now (fast region decoding);
  /// - PNG/WebP with native rendering: all tiles natively, from one decode;
  ///   if the image doesn't fit in memory, fall back to on-demand tiles;
  /// - anything else: all tiles in Dart.
  Future<int> _prepareTiles({
    required String imagePath,
    required String format,
    required int width,
    required int height,
    void Function(double progress)? onProgress,
  }) async {
    final maxZoom = TilePyramid(widthPx: width, heightPx: height).maxZoom;
    final native = nativeTiles;
    final tilesDir = p.join(p.dirname(imagePath), 'tiles');
    try {
      if (native != null &&
          NativeTileRenderer.supportedFormats.contains(format)) {
        if (NativeTileRenderer.onDemandFormats.contains(format)) {
          return maxZoom;
        }
        try {
          await native.generateAll(
            imagePath: imagePath,
            tilesDir: tilesDir,
            maxZoom: maxZoom,
            onProgress: onProgress,
          );
        } on ImageTooLargeException {
          // Slow on first view, but works for any size.
          await _deleteDir(tilesDir);
        }
        return maxZoom;
      }
      return await runWithProgress(
        _tilingTask(imagePath, tilesDir),
        onProgress: onProgress,
      );
    } catch (_) {
      // Don't leave a partial pyramid behind for a later retry to trip over.
      await _deleteDir(tilesDir);
      rethrow;
    }
  }

  static Future<void> _deleteDir(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // Built outside importImage so the closure sent to the isolate captures only
  // these two strings.
  static int Function(void Function(double)) _tilingTask(
    String imagePath,
    String tilesDir,
  ) =>
      (report) => generateTiles(imagePath, tilesDir, report);

  Future<void> rename(String id, String name) => (_db.update(
    _db.maps,
  )..where((m) => m.id.equals(id))).write(MapsCompanion(name: Value(name)));

  /// Sets the map's scale; null removes it.
  Future<void> setScale(String id, double? metersPerPixel) =>
      (_db.update(_db.maps)..where((m) => m.id.equals(id))).write(
        MapsCompanion(metersPerPixel: Value(metersPerPixel)),
      );

  /// Deletes the map, its markers and its stored image.
  Future<void> delete(String id) async {
    await (_db.delete(_db.maps)..where((m) => m.id.equals(id))).go();
    final dir = _mapDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Directory _mapDir(String id) =>
      Directory(p.join(_documentsDir.path, 'maps', id));

  MapProject _toProject(MapRow row) => MapProject(
    id: row.id,
    name: row.name,
    imagePath: p.join(_documentsDir.path, row.imageFile),
    widthPx: row.widthPx,
    heightPx: row.heightPx,
    createdAt: row.createdAt,
    tileMaxZoom: row.tileMaxZoom,
    metersPerPixel: row.metersPerPixel,
  );
}
