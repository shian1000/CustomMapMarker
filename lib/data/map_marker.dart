import 'package:flutter/foundation.dart';

@immutable
class MapMarker {
  const MapMarker({
    required this.id,
    required this.mapId,
    required this.x,
    required this.y,
    required this.label,
    this.description,
    required this.colorValue,
    required this.createdAt,
    this.icon,
  });

  final String id;
  final String mapId;

  /// Position normalized to the image (0..1, origin top-left).
  final double x;
  final double y;

  final String label;
  final String? description;

  /// ARGB color value.
  final int colorValue;
  final DateTime createdAt;

  /// Key from `markerIcons`, or null for the plain pin.
  final String? icon;

  MapMarker copyWith({
    double? x,
    double? y,
    String? label,
    ValueGetter<String?>? description,
    int? colorValue,
    ValueGetter<String?>? icon,
  }) => MapMarker(
    id: id,
    mapId: mapId,
    x: x ?? this.x,
    y: y ?? this.y,
    label: label ?? this.label,
    description: description != null ? description() : this.description,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt,
    icon: icon != null ? icon() : this.icon,
  );
}

/// User-editable marker fields, as produced by the marker editor.
@immutable
class MarkerDraft {
  const MarkerDraft({
    required this.label,
    this.description,
    required this.colorValue,
    this.icon,
  });

  final String label;
  final String? description;
  final int colorValue;
  final String? icon;
}
