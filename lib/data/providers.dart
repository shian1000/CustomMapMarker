import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/native_tile_renderer.dart';
import 'database.dart';
import 'image_file_picker.dart';
import 'map_marker.dart';
import 'map_project.dart';
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
