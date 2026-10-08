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

  Stream<List<MapProject>> watchMaps() {
    final query = _db.select(_db.maps)
      ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]);
    return query.watch().map((rows) => rows.map(_toProject).toList());
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

  MapProject _toProject(MapRow row) => MapProject(
    id: row.id,
    name: row.name,
    imagePath: p.join(_documentsDir.path, row.imageFile),
    widthPx: row.widthPx,
    heightPx: row.heightPx,
    createdAt: row.createdAt,
  );
}
