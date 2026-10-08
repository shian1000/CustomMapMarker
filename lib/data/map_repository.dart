import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/image_utils.dart';
import 'database.dart';
import 'map_project.dart';

class MapRepository {
  MapRepository(this._db, this._documentsDir);

  final AppDatabase _db;
  final Directory _documentsDir;

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

  /// Copies the image at [sourcePath] into app storage and saves it as a map.
  Future<MapProject> importImage(String sourcePath) async {
    final id = _uuid.v4();
    final dir = await Directory(p.join(_documentsDir.path, 'maps', id))
        .create(recursive: true);

    try {
      final image = await Isolate.run(
        () => prepareMapImage(sourcePath, dir.path),
      );
      final row = MapRow(
        id: id,
        name: p.basenameWithoutExtension(sourcePath),
        imageFile: p.relative(image.path, from: _documentsDir.path),
        widthPx: image.width,
        heightPx: image.height,
        createdAt: DateTime.now(),
      );
      await _db.into(_db.maps).insert(row);
      return _toProject(row);
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

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
  );
}
