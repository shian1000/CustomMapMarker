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
    this.renderTilesOnDemand = false,
  });

  /// Larger images exceed common GPU texture limits (and get blurry or fail
  /// to draw as one image), so they are shown as tiles.
  static const defaultTilingThresholdPx = 4096;

  final AppDatabase _db;
  final Directory _documentsDir;
  final int tilingThresholdPx;

  /// Whether tiles can be rendered natively while viewing (see
  /// NativeTileRenderer). If so, importing a large map only records its
  /// pyramid; otherwise all tiles are generated up front in Dart, which is
  /// much slower.
  final bool renderTilesOnDemand;

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
  /// and saves it as a map. [onProgress] receives 0..1 while tiling.
  Future<MapProject> importImage(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final id = _uuid.v4();
    final dir = await _mapDir(id).create(recursive: true);

    try {
      final image = await Isolate.run(
        () => prepareMapImage(sourcePath, dir.path),
      );

      int? tileMaxZoom;
      if (math.max(image.width, image.height) > tilingThresholdPx) {
        if (renderTilesOnDemand &&
            NativeTileRenderer.supportedFormats.contains(image.format)) {
          tileMaxZoom = TilePyramid(
            widthPx: image.width,
            heightPx: image.height,
          ).maxZoom;
        } else {
          tileMaxZoom = await runWithProgress(
            _tilingTask(image.path, p.join(dir.path, 'tiles')),
            onProgress: onProgress,
          );
        }
      }

      final row = MapRow(
        id: id,
        name: p.basenameWithoutExtension(sourcePath),
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
  );
}
