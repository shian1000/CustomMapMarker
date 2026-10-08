import 'dart:io';

import 'package:custom_map_marker/data/database.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_repository.dart';
import 'package:custom_map_marker/data/marker_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late Directory docs;
  late MapRepository maps;
  late MarkerRepository markers;

  const draft = MarkerDraft(label: 'Zamek', colorValue: 0xFFE53935);

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('docs');
    // Low threshold so a small test image gets tiled when wanted.
    maps = MapRepository(db, docs, tilingThresholdPx: 300);
    markers = MarkerRepository(db);
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  Future<String> importTestMap() async {
    final src = File(p.join(docs.path, 'Mapa świata.png'))
      ..writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 30)));
    final map = await maps.importImage(src.path);
    return map.id;
  }

  group('MapRepository', () {
    test('imports an image and lists it', () async {
      final id = await importTestMap();
      final listed = await maps.watchMaps().first;
      expect(listed, hasLength(1));
      final map = listed.single.map;
      expect(
        (map.id, map.name, map.widthPx, map.heightPx),
        (id, 'Mapa świata', 40, 30),
      );
      expect(map.imagePath, startsWith(docs.path));
      expect(File(map.imagePath).existsSync(), isTrue);
    });

    test('stores the image path relative to the documents directory', () async {
      await importTestMap();
      final row = await db.select(db.maps).getSingle();
      expect(p.isRelative(row.imageFile), isTrue);
    });

    test('cleans up copied files when the image is unsupported', () async {
      final src = File(p.join(docs.path, 'notes.txt'))..writeAsStringSync('x');
      await expectLater(maps.importImage(src.path), throwsA(anything));
      expect(Directory(p.join(docs.path, 'maps')).listSync(), isEmpty);
      expect(await maps.watchMaps().first, isEmpty);
    });

    test('lists newest first with marker counts', () async {
      final older = await importTestMap();
      // createdAt is stored with one-second precision.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final newer = await importTestMap();
      await markers.add(older, Offset.zero, draft);
      await markers.add(older, Offset.zero, draft);

      final listed = await maps.watchMaps().first;
      expect(
        [for (final s in listed) (s.map.id, s.markerCount)],
        [(newer, 0), (older, 2)],
      );
    });

    test('renames a map', () async {
      final id = await importTestMap();
      await maps.rename(id, 'Temeria');
      expect((await maps.watchMaps().first).single.map.name, 'Temeria');
    });

    test('deletes a map with its markers and image files', () async {
      final keep = await importTestMap();
      final gone = await importTestMap();
      await markers.add(gone, Offset.zero, draft);
      final goneImage = (await maps.watchMaps().first)
          .singleWhere((s) => s.map.id == gone)
          .map
          .imagePath;

      await maps.delete(gone);

      final listed = await maps.watchMaps().first;
      expect([for (final s in listed) s.map.id], [keep]);
      expect(await markers.watchMarkers(gone).first, isEmpty);
      expect(File(goneImage).existsSync(), isFalse);
      expect(Directory(p.join(docs.path, 'maps', gone)).existsSync(), isFalse);
      expect(Directory(p.join(docs.path, 'maps', keep)).existsSync(), isTrue);
    });
  });

  group('tiling', () {
    test('leaves images up to the threshold as a single image', () async {
      await importTestMap(); // 40×30
      final map = (await maps.watchMaps().first).single.map;
      expect(map.isTiled, isFalse);
      expect(Directory(map.tilesDir).existsSync(), isFalse);
    });

    test('tiles larger images and reports progress', () async {
      final src = File(p.join(docs.path, 'Duża.png'))
        ..writeAsBytesSync(img.encodePng(img.Image(width: 600, height: 300)));
      final progress = <double>[];

      final map = await maps.importImage(src.path, onProgress: progress.add);

      expect(map.tileMaxZoom, 2);
      expect(File(p.join(map.tilesDir, '2', '2', '1')).existsSync(), isTrue);
      expect(progress.last, closeTo(1, 1e-9));
      final stored = (await maps.watchMaps().first).single.map;
      expect(stored.tileMaxZoom, 2);
    });
  });

  group('on-demand tiling', () {
    late MapRepository onDemand;

    setUp(
      () => onDemand = MapRepository(
        db,
        docs,
        tilingThresholdPx: 300,
        renderTilesOnDemand: true,
      ),
    );

    Future<MapProject> importBig(String name, List<int> bytes) {
      final src = File(p.join(docs.path, name))..writeAsBytesSync(bytes);
      return onDemand.importImage(src.path);
    }

    final big = img.Image(width: 600, height: 300);

    test('records the pyramid without generating tiles', () async {
      final map = await importBig('big.png', img.encodePng(big));
      expect(map.tileMaxZoom, 2);
      expect(Directory(map.tilesDir).existsSync(), isFalse);
    });

    test(
      'still generates tiles for formats the renderer cannot read',
      () async {
        final map = await importBig('big.bmp', img.encodeBmp(big));
        expect(map.tileMaxZoom, 2);
        expect(File(p.join(map.tilesDir, '0', '0', '0')).existsSync(), isTrue);
      },
    );
  });

  group('MarkerRepository', () {
    test('adds markers and keeps maps apart', () async {
      final a = await importTestMap();
      final b = await importTestMap();
      final m = await markers.add(a, const Offset(0.2, 0.7), draft);

      final onA = await markers.watchMarkers(a).first;
      expect(onA.single.id, m.id);
      expect(
        (onA.single.x, onA.single.y, onA.single.label),
        (0.2, 0.7, 'Zamek'),
      );
      expect(await markers.watchMarkers(b).first, isEmpty);
    });

    test('edits fields, clears description and keeps position', () async {
      final mapId = await importTestMap();
      final m = await markers.add(
        mapId,
        const Offset(0.5, 0.5),
        const MarkerDraft(label: 'a', description: 'x', colorValue: 1),
      );
      await markers.edit(m.id, const MarkerDraft(label: 'b', colorValue: 2));

      final e = (await markers.watchMarkers(mapId).first).single;
      expect((e.label, e.description, e.colorValue), ('b', null, 2));
      expect((e.x, e.y), (0.5, 0.5));
    });

    test('moves a marker', () async {
      final mapId = await importTestMap();
      final m = await markers.add(mapId, Offset.zero, draft);
      await markers.move(m.id, const Offset(0.9, 0.1));
      final moved = (await markers.watchMarkers(mapId).first).single;
      expect((moved.x, moved.y), (0.9, 0.1));
    });

    test('removes and restores a marker with the same id', () async {
      final mapId = await importTestMap();
      final m = await markers.add(mapId, Offset.zero, draft);
      await markers.remove(m.id);
      expect(await markers.watchMarkers(mapId).first, isEmpty);
      await markers.restore(m);
      expect((await markers.watchMarkers(mapId).first).single.id, m.id);
    });

    test('deleting a map deletes its markers', () async {
      final mapId = await importTestMap();
      await markers.add(mapId, Offset.zero, draft);
      await (db.delete(db.maps)..where((m) => m.id.equals(mapId))).go();
      expect(await db.select(db.markers).get(), isEmpty);
    });
  });
}
