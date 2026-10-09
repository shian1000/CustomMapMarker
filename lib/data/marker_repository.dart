import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'map_marker.dart';

class MarkerRepository {
  MarkerRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  Stream<List<MapMarker>> watchMarkers(String mapId) {
    final query = _db.select(_db.markers)
      ..where((m) => m.mapId.equals(mapId))
      ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]);
    return query.watch().map((rows) => rows.map(_toMarker).toList());
  }

  Future<MapMarker> add(
    String mapId,
    Offset position,
    MarkerDraft draft,
  ) async {
    final marker = MapMarker(
      id: _uuid.v4(),
      mapId: mapId,
      x: position.dx,
      y: position.dy,
      label: draft.label,
      description: draft.description,
      colorValue: draft.colorValue,
      createdAt: DateTime.now(),
      icon: draft.icon,
    );
    await restore(marker);
    return marker;
  }

  Future<void> edit(String id, MarkerDraft draft) => _update(
    id,
    MarkersCompanion(
      label: Value(draft.label),
      description: Value(draft.description),
      colorValue: Value(draft.colorValue),
      icon: Value(draft.icon),
    ),
  );

  Future<void> move(String id, Offset position) => _update(
    id,
    MarkersCompanion(x: Value(position.dx), y: Value(position.dy)),
  );

  Future<void> remove(String id) =>
      (_db.delete(_db.markers)..where((m) => m.id.equals(id))).go();

  /// Saves [marker] as is, e.g. to undo its removal.
  Future<void> restore(MapMarker marker) =>
      _db.into(_db.markers).insert(_toRow(marker));

  Future<void> _update(String id, MarkersCompanion changes) =>
      (_db.update(_db.markers)..where((m) => m.id.equals(id))).write(changes);

  static MapMarker _toMarker(MarkerRow row) => MapMarker(
    id: row.id,
    mapId: row.mapId,
    x: row.x,
    y: row.y,
    label: row.label,
    description: row.description,
    colorValue: row.colorValue,
    createdAt: row.createdAt,
    icon: row.icon,
  );

  static MarkerRow _toRow(MapMarker m) => MarkerRow(
    id: m.id,
    mapId: m.mapId,
    x: m.x,
    y: m.y,
    label: m.label,
    description: m.description,
    colorValue: m.colorValue,
    createdAt: m.createdAt,
    icon: m.icon,
  );
}
