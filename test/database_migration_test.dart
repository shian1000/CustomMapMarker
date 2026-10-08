import 'package:custom_map_marker/data/database.dart';
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
      expect(
        (marker.label, marker.x, marker.colorValue),
        ('Novigrad', 0.5, 4293212469),
      );
      expect(raw.userVersion, 2);
    },
  );
}
