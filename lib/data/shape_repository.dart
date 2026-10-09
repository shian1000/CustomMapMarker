import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'map_shape.dart';

class ShapeRepository {
  ShapeRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Shapes of a map, oldest first (later ones are drawn on top).
  Stream<List<MapShape>> watchShapes(String mapId) {
    final query = _db.select(_db.shapes)
      ..where((s) => s.mapId.equals(mapId))
      ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]);
    return query.watch().map((rows) => rows.map(_toShape).toList());
  }

  Future<MapShape> add(
    String mapId,
    ShapeKind kind,
    List<Offset> points,
    ShapeStyle style,
  ) async {
    if (points.length < kind.minPoints) {
      throw ArgumentError('A ${kind.name} needs ${kind.minPoints} points');
    }
    final shape = MapShape(
      id: _uuid.v4(),
      mapId: mapId,
      kind: kind,
      points: List.unmodifiable(points),
      style: style,
      createdAt: DateTime.now(),
    );
    await restore(shape);
    return shape;
  }

  Future<void> updateStyle(String id, ShapeStyle style) => _update(
    id,
    ShapesCompanion(
      name: Value(style.name),
      description: Value(style.description),
      colorValue: Value(style.colorValue),
      strokeWidth: Value(style.width.index),
      dashed: Value(style.dashed),
      fillOpacity: Value(style.fillOpacity),
    ),
  );

  /// Replaces the points of shape [id] of the given [kind].
  Future<void> updatePoints(String id, ShapeKind kind, List<Offset> points) {
    if (points.length < kind.minPoints) {
      throw ArgumentError('A ${kind.name} needs ${kind.minPoints} points');
    }
    return _update(id, ShapesCompanion(points: Value(encodePoints(points))));
  }

  Future<void> _update(String id, ShapesCompanion changes) =>
      (_db.update(_db.shapes)..where((s) => s.id.equals(id))).write(changes);

  Future<void> remove(String id) =>
      (_db.delete(_db.shapes)..where((s) => s.id.equals(id))).go();

  /// Saves many [shapes] as they are, in one batch (e.g. an imported map).
  Future<void> insertAll(Iterable<MapShape> shapes) =>
      _db.batch((batch) => batch.insertAll(_db.shapes, shapes.map(_toRow)));

  /// Saves [shape] as is, e.g. to undo its removal.
  Future<void> restore(MapShape shape) =>
      _db.into(_db.shapes).insert(_toRow(shape));

  static String encodePoints(List<Offset> points) => jsonEncode([
    for (final p in points) [p.dx, p.dy],
  ]);

  static List<Offset> decodePoints(String json) => [
    for (final p in jsonDecode(json) as List)
      Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];

  static MapShape _toShape(ShapeRow row) => MapShape(
    id: row.id,
    mapId: row.mapId,
    kind: ShapeKind.values.byName(row.kind),
    points: decodePoints(row.points),
    style: ShapeStyle(
      name: row.name,
      description: row.description,
      colorValue: row.colorValue,
      width: ShapeWidth.values[row.strokeWidth.clamp(0, 2)],
      dashed: row.dashed,
      fillOpacity: row.fillOpacity,
    ),
    createdAt: row.createdAt,
  );

  static ShapeRow _toRow(MapShape s) => ShapeRow(
    id: s.id,
    mapId: s.mapId,
    kind: s.kind.name,
    name: s.style.name,
    description: s.style.description,
    colorValue: s.style.colorValue,
    strokeWidth: s.style.width.index,
    dashed: s.style.dashed,
    fillOpacity: s.style.fillOpacity,
    points: encodePoints(s.points),
    createdAt: s.createdAt,
  );
}
