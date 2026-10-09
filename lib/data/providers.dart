import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/native_tile_renderer.dart';
import 'database.dart';
import 'image_file_picker.dart';
import 'legend.dart';
import 'legend_repository.dart';
import 'map_marker.dart';
import 'map_project.dart';
import 'map_transfer.dart';
import 'map_repository.dart';
import 'marker_repository.dart';

/// App documents directory; resolved before startup and overridden in main.
final documentsDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('Override documentsDirProvider'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final imageFilePickerProvider = Provider((ref) => const ImageFilePicker());

final mapRepositoryProvider = Provider(
  (ref) => MapRepository(
    ref.watch(databaseProvider),
    ref.watch(documentsDirProvider),
    nativeTiles: NativeTileRenderer.isSupported
        ? const NativeTileRenderer()
        : null,
  ),
);

final markerRepositoryProvider = Provider(
  (ref) => MarkerRepository(ref.watch(databaseProvider)),
);

final mapsProvider = StreamProvider<List<MapSummary>>(
  (ref) => ref.watch(mapRepositoryProvider).watchMaps(),
);

final markersProvider = StreamProvider.autoDispose
    .family<List<MapMarker>, String>(
      (ref, mapId) => ref.watch(markerRepositoryProvider).watchMarkers(mapId),
    );

final legendRepositoryProvider = Provider(
  (ref) => LegendRepository(ref.watch(databaseProvider)),
);

final legendProvider = StreamProvider.autoDispose.family<MapLegend, String>(
  (ref, mapId) => ref.watch(legendRepositoryProvider).watchLegend(mapId),
);

final mapTransferProvider = Provider(
  (ref) => MapTransfer(
    maps: ref.watch(mapRepositoryProvider),
    markers: ref.watch(markerRepositoryProvider),
    legend: ref.watch(legendRepositoryProvider),
    workDir: Directory(
      p.join(ref.watch(documentsDirProvider).path, 'transfer'),
    ),
  ),
);
