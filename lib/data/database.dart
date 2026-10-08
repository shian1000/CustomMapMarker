import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('MapRow')
class Maps extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Image path relative to the app documents directory, which can move
  /// between app updates on iOS.
  TextColumn get imageFile => text()();
  IntColumn get widthPx => integer()();
  IntColumn get heightPx => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// Top zoom level of the tile pyramid in `tiles/` next to the image, or
  /// null when the map is small enough to be drawn as a single image.
  IntColumn get tileMaxZoom => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MarkerRow')
@TableIndex(name: 'markers_map_id', columns: {#mapId})
class Markers extends Table {
  TextColumn get id => text()();
  TextColumn get mapId =>
      text().references(Maps, #id, onDelete: KeyAction.cascade)();

  /// Position normalized to the image (0..1, origin top-left).
  RealColumn get x => real()();
  RealColumn get y => real()();
  TextColumn get label => text()();
  TextColumn get description => text().nullable()();

  /// ARGB color value.
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Maps, Markers])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'custom_map_marker'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Maps imported before tiling existed stay single-image maps.
        await m.addColumn(maps, maps.tileMaxZoom);
      }
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys (and so cascading deletes) off by default.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
