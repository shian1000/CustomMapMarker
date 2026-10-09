import 'package:custom_map_marker/features/map_view/shape_layers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('finds the point halfway along a route by length', () {
    // Lengths 3 and 1: halfway (2) lies on the first segment.
    final mid = midpointAlong(const [LatLng(0, 0), LatLng(0, 3), LatLng(1, 3)]);
    expect(mid.latitude, closeTo(0, 1e-9));
    expect(mid.longitude, closeTo(2, 1e-9));
  });

  test('handles a straight two-point route', () {
    final mid = midpointAlong(const [LatLng(0, 0), LatLng(-2, 4)]);
    expect((mid.latitude, mid.longitude), (-1.0, 2.0));
  });
}
