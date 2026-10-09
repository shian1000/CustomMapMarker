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

  /// Real-world meters per image pixel, set by calibrating the map's scale;
  /// null until then.
  RealColumn get metersPerPixel => real().nullable()();

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

  /// Key from `markerIcons`, or null for the plain pin.
  TextColumn get icon => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-map names for marker colors and whether markers of that color are
/// hidden by the filter. Colors without a row have no name and are shown.
@DataClassName('LegendRow')
class Legend extends Table {
  TextColumn get mapId =>
      text().references(Maps, #id, onDelete: KeyAction.cascade)();

  /// ARGB color value, as in [Markers.colorValue].
  IntColumn get colorValue => integer()();
  TextColumn get name => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {mapId, colorValue};
}

/// Routes (open lines) and areas (closed, filled polygons) drawn on a map.
@DataClassName('ShapeRow')
@TableIndex(name: 'shapes_map_id', columns: {#mapId})
class Shapes extends Table {
  TextColumn get id => text()();
  TextColumn get mapId =>
      text().references(Maps, #id, onDelete: KeyAction.cascade)();

  /// `route` or `area`.
  TextColumn get kind => text()();
  TextColumn get name => text().nullable()();
  TextColumn get description => text().nullable()();

  /// ARGB color value, shared with the legend like markers' colors.
  IntColumn get colorValue => integer()();

  /// Line width: 0 thin, 1 medium, 2 thick.
  IntColumn get strokeWidth => integer().withDefault(const Constant(1))();
  BoolColumn get dashed => boolean().withDefault(const Constant(false))();

  /// Fill opacity of areas, 0..1.
  RealColumn get fillOpacity => real().withDefault(const Constant(0.3))();

  /// JSON list of [x, y] pairs normalized to the image (0..1).
  TextColumn get points => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Maps, Markers, Legend, Shapes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'custom_map_marker'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Maps imported before tiling existed stay single-image maps.
        await m.addColumn(maps, maps.tileMaxZoom);
      }
      if (from < 3) {
        await m.createTable(legend);
      }
      if (from < 4) {
        await m.addColumn(markers, markers.icon);
      }
      if (from < 5) {
        await m.createTable(shapes);
        await m.createIndex(shapesMapId);
      }
      if (from < 6) {
        await m.addColumn(maps, maps.metersPerPixel);
      }
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys (and so cascading deletes) off by default.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
