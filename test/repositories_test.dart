import 'dart:io';

import 'package:custom_map_marker/data/database.dart';
import 'package:custom_map_marker/data/legend.dart';
import 'package:custom_map_marker/data/legend_repository.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_repository.dart';
import 'package:custom_map_marker/data/marker_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'fakes.dart';

void main() {
  late AppDatabase db;
  late Directory docs;
  late MapRepository maps;
  late MarkerRepository markers;
  late LegendRepository legend;

  const draft = MarkerDraft(label: 'Zamek', colorValue: 0xFFE53935);

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('docs');
    // Low threshold so a small test image gets tiled when wanted.
    maps = MapRepository(db, docs, tilingThresholdPx: 300);
    markers = MarkerRepository(db);
    legend = LegendRepository(db);
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

  group('naming', () {
    test('uses the given name instead of the file name', () async {
      final src = File(p.join(docs.path, '1000021497.png'))
        ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
      final map = await maps.importImage(src.path, name: 'Temeria');
      expect(map.name, 'Temeria');
      expect((await maps.watchMaps().first).single.map.name, 'Temeria');
    });
  });

  group('enableTiling', () {
    /// Imports [bytes] with tiling disabled, as maps were before stage 5.
    Future<MapProject> importUntiled(String name, List<int> bytes) {
      final src = File(p.join(docs.path, name))..writeAsBytesSync(bytes);
      return MapRepository(
        db,
        docs,
        tilingThresholdPx: 1 << 30,
      ).importImage(src.path);
    }

    final big = img.Image(width: 600, height: 300);

    test('generates tiles for an old large map', () async {
      final old = await importUntiled('old.png', img.encodePng(big));
      expect(maps.canEnableTiling(old), isTrue);
      final progress = <double>[];

      await maps.enableTiling(old, onProgress: progress.add);

      final updated = (await maps.watchMaps().first).single.map;
      expect(updated.tileMaxZoom, 2);
      expect(
        File(p.join(updated.tilesDir, '2', '2', '1')).existsSync(),
        isTrue,
      );
      expect(progress.last, closeTo(1, 1e-9));
      expect(maps.canEnableTiling(updated), isFalse);
    });

    test('only records the pyramid when tiles render on demand', () async {
      final old = await importUntiled('old.jpg', img.encodeJpg(big));
      final onDemand = MapRepository(
        db,
        docs,
        tilingThresholdPx: 300,
        nativeTiles: FakeNativeTiles(),
      );
      await onDemand.enableTiling(old);
      final updated = (await maps.watchMaps().first).single.map;
      expect(updated.tileMaxZoom, 2);
      expect(Directory(updated.tilesDir).existsSync(), isFalse);
    });

    test('is not offered for small maps', () async {
      await importTestMap(); // 40×30
      final small = (await maps.watchMaps().first).single.map;
      expect(maps.canEnableTiling(small), isFalse);
    });
  });

  group('native tiling', () {
    late FakeNativeTiles native;
    late MapRepository withNative;

    setUp(() {
      native = FakeNativeTiles();
      withNative = MapRepository(
        db,
        docs,
        tilingThresholdPx: 300,
        nativeTiles: native,
      );
    });

    Future<MapProject> importBig(
      String name,
      List<int> bytes, {
      void Function(double)? onProgress,
    }) {
      final src = File(p.join(docs.path, name))..writeAsBytesSync(bytes);
      return withNative.importImage(src.path, onProgress: onProgress);
    }

    final big = img.Image(width: 600, height: 300);

    test('leaves JPEG tiles to be rendered on demand', () async {
      final map = await importBig('big.jpg', img.encodeJpg(big));
      expect(map.tileMaxZoom, 2);
      expect(native.generated, isEmpty);
      expect(Directory(map.tilesDir).existsSync(), isFalse);
    });

    test('generates all PNG tiles natively at import', () async {
      final progress = <double>[];
      final map = await importBig(
        'big.png',
        img.encodePng(big),
        onProgress: progress.add,
      );
      expect(map.tileMaxZoom, 2);
      expect(native.generated, [(map.imagePath, map.tilesDir, 2)]);
      expect(progress, [1.0]);
    });

    test('falls back to on-demand tiles when the image is too large', () async {
      native.tooLarge = true;
      final map = await importBig('big.png', img.encodePng(big));
      expect(map.tileMaxZoom, 2);
      expect(Directory(map.tilesDir).existsSync(), isFalse);
    });

    test(
      'still generates tiles in Dart for formats the renderer cannot read',
      () async {
        final map = await importBig('big.bmp', img.encodeBmp(big));
        expect(map.tileMaxZoom, 2);
        expect(native.generated, isEmpty);
        expect(File(p.join(map.tilesDir, '0', '0', '0')).existsSync(), isTrue);
      },
    );
  });

  group('LegendRepository', () {
    const red = 0xFFE53935;
    const green = 0xFF43A047;

    test('names colors per map and clears blank names', () async {
      final a = await importTestMap();
      final b = await importTestMap();
      await legend.setName(a, red, '  Zamki ');
      expect((await legend.watchLegend(a).first).nameOf(red), 'Zamki');
      expect(await legend.watchLegend(b).first, isEmpty);

      await legend.setName(a, red, '   ');
      expect((await legend.watchLegend(a).first).nameOf(red), isNull);
    });

    test('hiding keeps the name and naming keeps it hidden', () async {
      final id = await importTestMap();
      await legend.setName(id, red, 'Zamki');
      await legend.setHidden(id, red, true);
      var l = await legend.watchLegend(id).first;
      expect((l.nameOf(red), l.isHidden(red)), ('Zamki', true));

      await legend.setName(id, red, 'Twierdze');
      l = await legend.watchLegend(id).first;
      expect((l.nameOf(red), l.isHidden(red)), ('Twierdze', true));
      expect(l.hasHidden, isTrue);
    });

    test('shows or hides many colors at once', () async {
      final id = await importTestMap();
      await legend.setAllHidden(id, [red, green], true);
      var l = await legend.watchLegend(id).first;
      expect((l.isHidden(red), l.isHidden(green)), (true, true));
      await legend.setAllHidden(id, [red, green], false);
      l = await legend.watchLegend(id).first;
      expect(l.hasHidden, isFalse);
    });

    test('is deleted with its map', () async {
      final id = await importTestMap();
      await legend.setName(id, red, 'Zamki');
      await maps.delete(id);
      expect(await db.select(db.legend).get(), isEmpty);
    });
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
