import 'package:drift/drift.dart';

import 'database.dart';
import 'legend.dart';

class LegendRepository {
  LegendRepository(this._db);

  final AppDatabase _db;

  Stream<MapLegend> watchLegend(String mapId) =>
      (_db.select(_db.legend)..where((l) => l.mapId.equals(mapId))).watch().map(
        (rows) => {
          for (final row in rows)
            row.colorValue: LegendEntry(name: row.name, hidden: row.hidden),
        },
      );

  /// Names [colorValue] on this map; a null or blank [name] clears it.
  Future<void> setName(String mapId, int colorValue, String? name) {
    final trimmed = name?.trim();
    return _upsert(
      mapId,
      colorValue,
      LegendCompanion(
        name: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  Future<void> setHidden(String mapId, int colorValue, bool hidden) =>
      _upsert(mapId, colorValue, LegendCompanion(hidden: Value(hidden)));

  /// Shows or hides all of [colorValues] at once.
  Future<void> setAllHidden(
    String mapId,
    Iterable<int> colorValues,
    bool hidden,
  ) => _db.transaction(() async {
    for (final color in colorValues) {
      await setHidden(mapId, color, hidden);
    }
  });

  /// Updates only the fields set in [changes], creating the row if needed.
  Future<void> _upsert(String mapId, int colorValue, LegendCompanion changes) =>
      _db
          .into(_db.legend)
          .insert(
            changes.copyWith(
              mapId: Value(mapId),
              colorValue: Value(colorValue),
            ),
            onConflict: DoUpdate((_) => changes),
          );
}
