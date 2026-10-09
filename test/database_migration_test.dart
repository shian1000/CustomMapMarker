import 'package:custom_map_marker/data/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'upgrades a version 1 database without losing maps or markers',
    () async {
      // Schema exactly as shipped in version 1.
      final raw = sqlite3.openInMemory()
        ..execute('''
        CREATE TABLE maps (
          id TEXT NOT NULL, name TEXT NOT NULL, image_file TEXT NOT NULL,
          width_px INTEGER NOT NULL, height_px INTEGER NOT NULL,
          created_at INTEGER NOT NULL, PRIMARY KEY (id));
        CREATE TABLE markers (
          id TEXT NOT NULL,
          map_id TEXT NOT NULL REFERENCES maps (id) ON DELETE CASCADE,
          x REAL NOT NULL, y REAL NOT NULL, label TEXT NOT NULL,
          description TEXT NULL, color_value INTEGER NOT NULL,
          created_at INTEGER NOT NULL, PRIMARY KEY (id));
        CREATE INDEX markers_map_id ON markers (map_id);
        INSERT INTO maps VALUES ('m1', 'Wiedźmin', 'maps/m1/map.jpg',
          5000, 4000, 1791450000);
        INSERT INTO markers VALUES ('k1', 'm1', 0.5, 0.25, 'Novigrad', NULL,
          4293212469, 1791450000);
        PRAGMA user_version = 1;
      ''');

      final db = AppDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final map = await db.select(db.maps).getSingle();
      expect(
        (map.name, map.widthPx, map.tileMaxZoom),
        ('Wiedźmin', 5000, null),
      );
      final marker = await db.select(db.markers).getSingle();
      expect(marker.icon, isNull);
      expect(
        (marker.label, marker.x, marker.colorValue),
        ('Novigrad', 0.5, 4293212469),
      );
      expect(raw.userVersion, 5);
      await db
          .into(db.legend)
          .insert(
            LegendCompanion.insert(
              mapId: 'm1',
              colorValue: 1,
              name: const Value('Zamki'),
            ),
          );
      expect((await db.select(db.legend).getSingle()).name, 'Zamki');
      expect(await db.select(db.shapes).get(), isEmpty);
    },
  );

  test('upgrades a version 2 database by adding the legend', () async {
    final raw = sqlite3.openInMemory()
      ..execute('''
        CREATE TABLE maps (
          id TEXT NOT NULL, name TEXT NOT NULL, image_file TEXT NOT NULL,
          width_px INTEGER NOT NULL, height_px INTEGER NOT NULL,
          created_at INTEGER NOT NULL, tile_max_zoom INTEGER NULL,
          PRIMARY KEY (id));
        CREATE TABLE markers (
          id TEXT NOT NULL,
          map_id TEXT NOT NULL REFERENCES maps (id) ON DELETE CASCADE,
          x REAL NOT NULL, y REAL NOT NULL, label TEXT NOT NULL,
          description TEXT NULL, color_value INTEGER NOT NULL,
          created_at INTEGER NOT NULL, PRIMARY KEY (id));
        CREATE INDEX markers_map_id ON markers (map_id);
        INSERT INTO maps VALUES ('m1', 'Wiedźmin', 'maps/m1/map.png',
          5456, 7567, 1791450000, 5);
        PRAGMA user_version = 2;
      ''');

    final db = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    expect((await db.select(db.maps).getSingle()).tileMaxZoom, 5);
    expect(await db.select(db.legend).get(), isEmpty);
    expect(raw.userVersion, 5);
  });
}
