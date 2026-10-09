import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/map_archive.dart';
import 'legend.dart';
import 'legend_repository.dart';
import 'map_marker.dart';
import 'map_project.dart';
import 'map_shape.dart';
import 'map_repository.dart';
import 'marker_repository.dart';
import 'shape_repository.dart';

/// Exports a map with its markers and legend to a `.cmm` file (a ZIP with
/// `manifest.json` and the image) and imports such files as new maps.
class MapTransfer {
  MapTransfer({
    required this.maps,
    required this.markers,
    required this.legend,
    required this.shapes,
    required this.workDir,
  });

  static const fileExtension = 'cmm';
  static const _format = 'custom-map-marker';

  /// Bump when the manifest changes in a way older versions can't read.
  /// 2: routes and areas ("shapes").
  static const formatVersion = 2;

  final MapRepository maps;
  final MarkerRepository markers;
  final LegendRepository legend;
  final ShapeRepository shapes;

  /// Scratch space for files being exported or imported.
  final Directory workDir;

  static const _uuid = Uuid();

  /// Writes [map] to a `.cmm` file and returns its path. The previous export
  /// is removed, since it has been handed to the share sheet already.
  Future<String> export(MapProject map) async {
    final mapMarkers = await markers.watchMarkers(map.id).first;
    final mapLegend = await legend.watchLegend(map.id).first;
    final mapShapes = await shapes.watchShapes(map.id).first;
    final imageEntry = 'image${p.extension(map.imagePath)}';

    final manifest = jsonEncode({
      'format': _format,
      'version': formatVersion,
      'map': {
        'name': map.name,
        'widthPx': map.widthPx,
        'heightPx': map.heightPx,
        'image': imageEntry,
        // Optional, so files without it stay version 2.
        'metersPerPixel': ?map.metersPerPixel,
      },
      'markers': [
        for (final m in mapMarkers)
          {
            'label': m.label,
            'description': ?m.description,
            'x': m.x,
            'y': m.y,
            'colorValue': m.colorValue,
            'icon': ?m.icon,
            'createdAt': m.createdAt.toUtc().toIso8601String(),
          },
      ],
      'legend': [
        for (final MapEntry(key: color, value: entry) in mapLegend.entries)
          {'colorValue': color, 'name': ?entry.name, 'hidden': entry.hidden},
      ],
      'shapes': [
        for (final s in mapShapes)
          {
            'kind': s.kind.name,
            'name': ?s.name,
            'description': ?s.style.description,
            'colorValue': s.colorValue,
            'width': s.style.width.name,
            'dashed': s.style.dashed,
            'fillOpacity': s.style.fillOpacity,
            'points': [
              for (final p in s.points) [p.dx, p.dy],
            ],
            'createdAt': s.createdAt.toUtc().toIso8601String(),
          },
      ],
    });

    final dir = Directory(p.join(workDir.path, 'export'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final zipPath = p.join(
      dir.path,
      '${safeFileName(map.name)}.$fileExtension',
    );
    final imagePath = map.imagePath;
    await Isolate.run(
      () => writeMapArchive(
        zipPath: zipPath,
        manifestJson: manifest,
        imagePath: imagePath,
        imageEntry: imageEntry,
      ),
    );
    return zipPath;
  }

  /// Imports the `.cmm` file at [path] as a new map, with new ids so nothing
  /// existing is overwritten. Throws [MapArchiveException] for files that
  /// aren't valid map files.
  Future<MapProject> import(
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = Directory(p.join(workDir.path, 'import-${_uuid.v4()}'));
    await dir.create(recursive: true);
    try {
      final extractDir = dir.path;
      final read = await Isolate.run(
        () => readMapArchive(
          zipPath: path,
          extractDir: extractDir,
          imageEntryOf: imageEntryOfManifest,
        ),
      );
      final manifest = _Manifest.parse(read.manifestJson);

      final map = await maps.importImage(
        read.imagePath,
        name: manifest.name,
        onProgress: onProgress,
      );
      try {
        if (manifest.metersPerPixel case final scale?) {
          await maps.setScale(map.id, scale);
        }
        await markers.insertAll([
          for (final m in manifest.markers)
            MapMarker(
              id: _uuid.v4(),
              mapId: map.id,
              x: m.x,
              y: m.y,
              label: m.label,
              description: m.description,
              colorValue: m.colorValue,
              icon: m.icon,
              createdAt: m.createdAt,
            ),
        ]);
        await shapes.insertAll([
          for (final s in manifest.shapes)
            MapShape(
              id: _uuid.v4(),
              mapId: map.id,
              kind: s.kind,
              points: s.points,
              style: s.style,
              createdAt: s.createdAt,
            ),
        ]);
        for (final MapEntry(key: color, value: entry)
            in manifest.legend.entries) {
          if (entry.name != null) {
            await legend.setName(map.id, color, entry.name);
          }
          if (entry.hidden) await legend.setHidden(map.id, color, true);
        }
      } catch (_) {
        await maps.delete(map.id);
        rethrow;
      }
      return map;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// [name] made safe to use as a file name on any platform.
  static String safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    return cleaned.isEmpty ? 'mapa' : cleaned;
  }
}

/// The image entry named by a manifest; throws [MapArchiveException] if the
/// manifest is unusable, so the reason (e.g. a newer format) isn't lost.
/// Top-level so it can be sent to the isolate that reads the archive.
String imageEntryOfManifest(String manifestJson) =>
    _Manifest.parse(manifestJson).imageEntry;

class _ManifestMarker {
  const _ManifestMarker({
    required this.label,
    required this.description,
    required this.x,
    required this.y,
    required this.colorValue,
    required this.icon,
    required this.createdAt,
  });

  final String label;
  final String? description;
  final double x;
  final double y;
  final int colorValue;
  final String? icon;
  final DateTime createdAt;
}

/// A route or area as read from a manifest, before it gets an id.
class _ManifestShape {
  const _ManifestShape(this.kind, this.points, this.style, this.createdAt);

  final ShapeKind kind;
  final List<Offset> points;
  final ShapeStyle style;
  final DateTime createdAt;
}

class _Manifest {
  const _Manifest({
    required this.name,
    required this.imageEntry,
    required this.markers,
    required this.legend,
    required this.shapes,
    this.metersPerPixel,
  });

  final String name;
  final double? metersPerPixel;
  final String imageEntry;
  final List<_ManifestMarker> markers;
  final MapLegend legend;
  final List<_ManifestShape> shapes;

  /// Validates and reads a manifest. A file from another app is
  /// [MapArchiveError.notAMapFile], a newer format is
  /// [MapArchiveError.newerVersion], anything else malformed is
  /// [MapArchiveError.damaged].
  static _Manifest parse(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw MapArchiveException(MapArchiveError.damaged, '$e');
    }
    if (root is! Map<String, Object?> ||
        root['format'] != MapTransfer._format) {
      throw const MapArchiveException(MapArchiveError.notAMapFile);
    }
    final version = root['version'];
    if (version is! int) {
      throw const MapArchiveException(MapArchiveError.damaged, 'no version');
    }
    if (version > MapTransfer.formatVersion) {
      throw MapArchiveException(MapArchiveError.newerVersion, 'v$version');
    }

    try {
      final map = root['map']! as Map<String, Object?>;
      return _Manifest(
        name: map['name']! as String,
        imageEntry: map['image']! as String,
        metersPerPixel: switch ((map['metersPerPixel'] as num?)?.toDouble()) {
          null => null,
          final v when v > 0 && v.isFinite => v,
          final v => throw MapArchiveException(
            MapArchiveError.damaged,
            'metersPerPixel=$v',
          ),
        },
        markers: [
          for (final m in (root['markers'] ?? const []) as List)
            _parseMarker(m as Map<String, Object?>),
        ],
        legend: {
          for (final e in (root['legend'] ?? const []) as List)
            (e as Map<String, Object?>)['colorValue']! as int: LegendEntry(
              name: e['name'] as String?,
              hidden: (e['hidden'] as bool?) ?? false,
            ),
        },
        // Absent in version 1 files.
        shapes: [
          for (final e in (root['shapes'] ?? const []) as List)
            _parseShape(e as Map<String, Object?>),
        ],
      );
    } on TypeError catch (e) {
      throw MapArchiveException(MapArchiveError.damaged, '$e');
    }
  }

  static _ManifestShape _parseShape(Map<String, Object?> s) {
    final ShapeKind kind;
    final ShapeWidth width;
    try {
      kind = ShapeKind.values.byName(s['kind']! as String);
      width = ShapeWidth.values.byName((s['width'] as String?) ?? 'medium');
    } on ArgumentError catch (e) {
      throw MapArchiveException(MapArchiveError.damaged, '$e');
    }
    final points = [
      for (final p in s['points']! as List)
        Offset(
          _unit(((p as List)[0] as num).toDouble(), 'x'),
          _unit((p[1] as num).toDouble(), 'y'),
        ),
    ];
    if (points.length < kind.minPoints) {
      throw MapArchiveException(
        MapArchiveError.damaged,
        '${kind.name} with ${points.length} points',
      );
    }
    final opacity = ((s['fillOpacity'] as num?) ?? 0.3).toDouble();
    return _ManifestShape(
      kind,
      points,
      ShapeStyle(
        name: s['name'] as String?,
        description: s['description'] as String?,
        colorValue: s['colorValue']! as int,
        width: width,
        dashed: (s['dashed'] as bool?) ?? false,
        fillOpacity: _unit(opacity, 'fillOpacity'),
      ),
      DateTime.tryParse(s['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  /// [value] if it lies in 0..1; otherwise the file is damaged.
  static double _unit(double value, String what) {
    if (value < 0 || value > 1) {
      throw MapArchiveException(MapArchiveError.damaged, '$what=$value');
    }
    return value;
  }

  static _ManifestMarker _parseMarker(Map<String, Object?> m) {
    double position(String key) {
      final value = (m[key]! as num).toDouble();
      if (value < 0 || value > 1) {
        throw MapArchiveException(MapArchiveError.damaged, '$key=$value');
      }
      return value;
    }

    return _ManifestMarker(
      label: m['label']! as String,
      description: m['description'] as String?,
      x: position('x'),
      y: position('y'),
      colorValue: m['colorValue']! as int,
      icon: m['icon'] as String?,
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
