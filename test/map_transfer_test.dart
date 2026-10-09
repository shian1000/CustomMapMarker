import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:custom_map_marker/core/map_archive.dart';
import 'package:custom_map_marker/data/database.dart';
import 'package:custom_map_marker/data/legend.dart';
import 'package:custom_map_marker/data/legend_repository.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_repository.dart';
import 'package:custom_map_marker/data/map_transfer.dart';
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
  late LegendRepository legend;
  late MapTransfer transfer;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('transfer');
    maps = MapRepository(db, docs);
    markers = MarkerRepository(db);
    legend = LegendRepository(db);
    transfer = MapTransfer(
      maps: maps,
      markers: markers,
      legend: legend,
      workDir: Directory(p.join(docs.path, 'transfer')),
    );
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  Future<MapProject> mapWithContent() async {
    final src = File(p.join(docs.path, 'src.png'))
      ..writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 30)));
    final map = await maps.importImage(src.path, name: 'Świat: Wiedźmin/2');
    await markers.add(
      map.id,
      const Offset(0.25, 0.75),
      const MarkerDraft(
        label: 'Wyzima',
        description: 'Stolica Temerii',
        colorValue: 0xFFE53935,
        icon: 'castle',
      ),
    );
    await markers.add(
      map.id,
      const Offset(0.5, 0.1),
      const MarkerDraft(label: 'Las', colorValue: 0xFF43A047),
    );
    await legend.setName(map.id, 0xFFE53935, 'Miasta');
    await legend.setHidden(map.id, 0xFF43A047, true);
    return map;
  }

  String writeZip(Map<String, List<int>> entries) {
    final path = p.join(docs.path, 'test.cmm');
    final archive = Archive();
    entries.forEach(
      (name, bytes) => archive.add(ArchiveFile.bytes(name, bytes)),
    );
    File(path).writeAsBytesSync(ZipEncoder().encode(archive));
    return path;
  }

  List<int> manifest(Map<String, Object?> overrides) => utf8.encode(
    jsonEncode({
      'format': 'custom-map-marker',
      'version': 1,
      'map': {'name': 'X', 'widthPx': 4, 'heightPx': 4, 'image': 'image.png'},
      'markers': <Object>[],
      ...overrides,
    }),
  );

  final pngBytes = img.encodePng(img.Image(width: 4, height: 4));

  Future<MapArchiveError?> importError(String path) async {
    try {
      await transfer.import(path);
      return null;
    } on MapArchiveException catch (e) {
      return e.error;
    }
  }

  test('round-trips a map with markers, icons and legend', () async {
    final original = await mapWithContent();
    final file = await transfer.export(original);
    expect(p.basename(file), 'Świat_ Wiedźmin_2.cmm');

    final copy = await transfer.import(file);

    expect(copy.id, isNot(original.id));
    expect(
      (copy.name, copy.widthPx, copy.heightPx),
      ('Świat: Wiedźmin/2', 40, 30),
    );
    expect(File(copy.imagePath).existsSync(), isTrue);

    final copied = await markers.watchMarkers(copy.id).first;
    final byLabel = {for (final m in copied) m.label: m};
    expect(byLabel.keys.toSet(), {'Wyzima', 'Las'});
    final wyzima = byLabel['Wyzima']!;
    expect(
      (wyzima.x, wyzima.y, wyzima.description, wyzima.icon, wyzima.colorValue),
      (0.25, 0.75, 'Stolica Temerii', 'castle', 0xFFE53935),
    );
    expect(byLabel['Las']!.icon, isNull);
    final originalIds = (await markers.watchMarkers(original.id).first)
        .map((m) => m.id)
        .toSet();
    expect(copied.map((m) => m.id).toSet().intersection(originalIds), isEmpty);

    final copiedLegend = await legend.watchLegend(copy.id).first;
    expect(copiedLegend.nameOf(0xFFE53935), 'Miasta');
    expect(copiedLegend.isHidden(0xFF43A047), isTrue);

    // The original is untouched and scratch files are gone.
    expect(await maps.watchMaps().first, hasLength(2));
    expect(
      Directory(p.join(docs.path, 'transfer'))
          .listSync()
          .where((e) => p.basename(e.path).startsWith('import-')),
      isEmpty,
    );
  });

  test('stores the image uncompressed', () async {
    final file = await transfer.export(await mapWithContent());
    final archive = ZipDecoder().decodeBytes(File(file).readAsBytesSync());
    expect(archive.find('image.png')!.compression, CompressionType.none);
  });

  test('rejects files that are not map files', () async {
    final notZip = File(p.join(docs.path, 'notes.cmm'))
      ..writeAsStringSync('hello');
    expect(await importError(notZip.path), MapArchiveError.notAMapFile);
    expect(
      await importError(writeZip({'readme.txt': utf8.encode('x')})),
      MapArchiveError.notAMapFile,
    );
    expect(
      await importError(
        writeZip({
          'manifest.json': manifest({'format': 'other-app'}),
        }),
      ),
      MapArchiveError.notAMapFile,
    );
  });

  test('rejects files from a newer app version', () async {
    final path = writeZip({
      'manifest.json': manifest({'version': 99}),
      'image.png': pngBytes,
    });
    expect(await importError(path), MapArchiveError.newerVersion);
  });

  test('rejects damaged files and leaves no map behind', () async {
    expect(
      await importError(writeZip({'manifest.json': manifest({})})),
      MapArchiveError.damaged,
    );
    expect(
      await importError(
        writeZip({
          'manifest.json': manifest({
            'markers': [
              {'label': 'Poza', 'x': 1.5, 'y': 0.5, 'colorValue': 1},
            ],
          }),
          'image.png': pngBytes,
        }),
      ),
      MapArchiveError.damaged,
    );
    expect(
      await importError(writeZip({'manifest.json': utf8.encode('{nope')})),
      MapArchiveError.damaged,
    );
    expect(await maps.watchMaps().first, isEmpty);
  });

  test('keeps extracted files inside the scratch directory', () async {
    final path = writeZip({
      'manifest.json': manifest({
        'map': {
          'name': 'X',
          'widthPx': 4,
          'heightPx': 4,
          'image': '../../escape.png',
        },
      }),
      '../../escape.png': pngBytes,
    });
    final map = await transfer.import(path);
    expect(File(p.join(docs.path, '..', 'escape.png')).existsSync(), isFalse);
    expect(File(map.imagePath).existsSync(), isTrue);
  });

  test('makes safe file names', () {
    expect(
      MapTransfer.safeFileName('a/b\\c:d*e?f"g<h>i|j'),
      'a_b_c_d_e_f_g_h_i_j',
    );
    expect(MapTransfer.safeFileName('   '), 'mapa');
  });
}
