import 'package:flutter/foundation.dart';

@immutable
class MapProject {
  const MapProject({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Copy of the imported image inside the app documents directory.
  final String imagePath;
  final int widthPx;
  final int heightPx;
  final DateTime createdAt;
}
