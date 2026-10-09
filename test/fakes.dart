import 'dart:async';

import 'dart:io';
import 'dart:ui';

import 'package:custom_map_marker/core/native_tile_renderer.dart';
import 'package:custom_map_marker/data/image_file_picker.dart';
import 'package:custom_map_marker/data/legend_repository.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/marker_repository.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_repository.dart';

MapProject testMap(
  String id, {
  String name = 'Mapa',
  int width = 100,
  int height = 100,
  int? tileMaxZoom,
}) => MapProject(
  id: id,
  name: name,
  imagePath: '/nonexistent/$id.png',
  widthPx: width,
  heightPx: height,
  createdAt: DateTime(2026),
  tileMaxZoom: tileMaxZoom,
);

/// In-memory stand-in for [MapRepository] that records calls.
class FakeMapRepository implements MapRepository {
  FakeMapRepository([List<MapSummary> maps = const []]) : _maps = [...maps];

  final List<MapSummary> _maps;
  final _changes = StreamController<List<MapSummary>>.broadcast();

  final renamed = <(String, String)>[];
  final deleted = <String>[];
  final imported = <(String path, String? name)>[];
  final tiled = <String>[];

  /// Ids for which [canEnableTiling] is true.
  final tileable = <String>{};

  @override
  Stream<List<MapSummary>> watchMaps() async* {
    yield List.of(_maps);
    yield* _changes.stream;
  }

  @override
  Future<void> rename(String id, String name) async {
    renamed.add((id, name));
    final i = _maps.indexWhere((s) => s.map.id == id);
    if (i >= 0) {
      final old = _maps[i].map;
      _maps[i] = MapSummary(
        map: MapProject(
          id: old.id,
          name: name,
          imagePath: old.imagePath,
          widthPx: old.widthPx,
          heightPx: old.heightPx,
          createdAt: old.createdAt,
          tileMaxZoom: old.tileMaxZoom,
        ),
        markerCount: _maps[i].markerCount,
      );
      _changes.add(List.of(_maps));
    }
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<MapProject> importImage(
    String sourcePath, {
    String? name,
    void Function(double progress)? onProgress,
  }) async {
    imported.add((sourcePath, name));
    return testMap('imported', name: name ?? 'x');
  }

  @override
  bool canEnableTiling(MapProject map) => tileable.contains(map.id);

  @override
  Future<void> enableTiling(
    MapProject map, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    tiled.add(map.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeImageFilePicker implements ImageFilePicker {
  FakeImageFilePicker(this.result);

  final PickedImage? result;

  @override
  Future<PickedImage?> pick() async => result;
}

/// Records whole-pyramid requests instead of calling the platform.
class FakeNativeTiles implements NativeTileRenderer {
  final generated = <(String imagePath, String tilesDir, int maxZoom)>[];

  /// Makes [generateAll] report the image as too large to decode at once,
  /// after writing a partial tile like a real failure could.
  bool tooLarge = false;

  @override
  Future<void> generateAll({
    required String imagePath,
    required String tilesDir,
    required int maxZoom,
    void Function(double progress)? onProgress,
  }) async {
    File('$tilesDir/0/0/0')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(const [0]);
    if (tooLarge) throw const ImageTooLargeException('test');
    generated.add((imagePath, tilesDir, maxZoom));
    onProgress?.call(1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records legend changes instead of storing them.
class FakeLegendRepository implements LegendRepository {
  final names = <(String mapId, int color, String? name)>[];
  final hidden = <(String mapId, int color, bool hidden)>[];

  @override
  Future<void> setName(String mapId, int colorValue, String? name) async =>
      names.add((mapId, colorValue, name));

  @override
  Future<void> setHidden(String mapId, int colorValue, bool hidden) async =>
      this.hidden.add((mapId, colorValue, hidden));

  @override
  Future<void> setAllHidden(
    String mapId,
    Iterable<int> colorValues,
    bool hidden,
  ) async {
    for (final c in colorValues) {
      await setHidden(mapId, c, hidden);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records added markers instead of storing them.
class FakeMarkerRepository implements MarkerRepository {
  final added = <(String mapId, MarkerDraft draft)>[];

  @override
  Future<MapMarker> add(
    String mapId,
    Offset position,
    MarkerDraft draft,
  ) async {
    added.add((mapId, draft));
    return MapMarker(
      id: 'new',
      mapId: mapId,
      x: position.dx,
      y: position.dy,
      label: draft.label,
      colorValue: draft.colorValue,
      createdAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MapMarker testMarker(
  String id,
  String label, {
  required int color,
  double x = 0.5,
  double y = 0.5,
}) => MapMarker(
  id: id,
  mapId: 'map',
  x: x,
  y: y,
  label: label,
  colorValue: color,
  createdAt: DateTime(2026),
);
